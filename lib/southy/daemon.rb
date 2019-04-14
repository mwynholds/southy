class Southy::Daemon

  def initialize(travel_agent)
    @agent = travel_agent
    @config = travel_agent.config
    @active = true
    @paused = false
  end

  def slackbot=(slackbot)
    @slackbot = slackbot
  end

  def start(daemonize = true)
    Process.daemon if daemonize
    write_pid

    [ 'HUP', 'INT', 'QUIT', 'TERM' ].each do |sig|
      Signal.trap(sig) do
        @config.log "Interrupted with signal: #{sig}"
        kill
      end
    end

    begin
      @slackthread = Thread.new { @slackbot.run }
      run
    rescue => e
      @config.log "Unexpected error", e
    ensure
      cleanup
    end
  end

  def pause
    @paused = true
    @config.log "Daemon paused"
  end

  def resume
    @paused = false
    @config.log "Daemon resumed"
  end

  def cleanup
    delete_pid
  end

  private

  def run
    @config.log "Southy is running."
    attempts = {}
    running = {}
    while active? do
      if ! @paused
        @config.reload

        @config.unconfirmed.each do |flight|
          @agent.confirm(flight)
        end

        groups = @config.upcoming.group_by { |flight| { :conf => flight.conf, :number => flight.number } }
        groups.values.each do |flights|
          flight = flights[0]
          attempts[flight.conf] ||= 0
          if flight.checkin_available?
            if attempts[flight.conf] <= 5 || flight.checkin_time? || flight.late_checkin_time?
              unless running[flight.conf]
                running[flight.conf] = true
                @config.log "Ready to check in flight #{flight.conf} (#{flight.full_name})" if Debug.is_debug?
                Thread.abort_on_exception = true
                Thread.new do
                  checked_in = @agent.checkin(flights)
                  if checked_in.empty?
                    attempts[flight.conf] += 1
                  else
                    attempts.delete flight.conf
                  end
                  running.delete flight.conf
                end
              end
            end
          end
        end
      end

      sleep 0.5
    end
    @config.log "Southy got killed"
    @slackthread.kill
  end

  def active?
    @active
  end

  def kill
    @active = false
  end

  def write_pid
    File.open @config.pid_file, 'w' do |f|
      f.write Process.pid.to_s
    end
  end

  def delete_pid
    File.delete @config.pid_file if File.exists? @config.pid_file
  end
end
