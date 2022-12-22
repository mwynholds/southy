module Southy
  class Service

    def initialize(config, travel_agent, slackbot)
      @config = config
      @agent = travel_agent
      @slackbot = slackbot
    end

    def run
      STDOUT.sync = true
      puts "Southy is running with env #{@config.env}."
      Thread.abort_on_exception = true
      Thread.report_on_exception = false if defined? Thread.report_on_exception
      # Thread.new { @slackbot.run }
      sleep 1
      checkin_loop
    end

    private

    def checkin_loop
      running = {}
      loop do
        # bounds = Bound.upcoming.uniq { |b| b.reservation.conf }
        bounds = Bound.upcoming
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
    end
  end
end
