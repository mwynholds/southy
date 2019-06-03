module Southy
  class Daemon

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
          bounds = Bound.upcoming
          bounds.each do |b|
            r = b.reservation
            attempts[r.conf] ||= 0

            if b.checkin_available?
              if attempts[r.conf] <= 5 || b.checkin_time? || b.late_checkin_time?
                next if running[r.conf]

                running[r.conf] = true
                Thread.abort_on_exception = true
                Thread.new do
                  begin
                    checked_in = @agent.checkin b
                    attemps.delete r.conf
                  rescue SouthyException => e
                    attemps[r.conf] += 1
                  end
                  running.delete r.conf
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
end
