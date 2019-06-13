module Southy
  class Daemon

    def initialize(travel_agent)
      @agent = travel_agent
      @config = travel_agent.config
      @active = true
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
        sleep 1
        run
      rescue => e
        @config.log "Unexpected error", e
      ensure
        cleanup
      end
    end

    def cleanup
      delete_pid
    end

    private

    def run
      @config.log "Southy is running."
      Thread.abort_on_exception = true
      running = {}
      while active? do
        bounds = Bound.upcoming.uniq { |b| b.reservation.conf }
        bounds.each do |b|
          next unless b.ready_for_checkin?

          r = b.reservation
          next if running[r.conf]

          seats = nil
          Thread.new do
            begin
              running[r.conf] = true
              checked_in = @agent.checkin b
              seats =  checked_in ? b.seats_ident : "unable to check in"
            rescue SouthyException => e
              seats = e.message
            ensure
              running.delete r.conf
              puts "Checked in #{r.conf} (SW#{b.flights.first}) for #{r.passengers_ident} : #{seats}"
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
