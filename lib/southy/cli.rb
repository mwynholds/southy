module Southy

  class CLI
    def initialize(opts)
      @options = { :verbose => false, :write => false }.merge opts
      check_options

      @config = Config.new
      @agent = TravelAgent.new(@config)
      slackbot = Slackbot.new(@config, @agent)
      daemon = Daemon.new(@agent, slackbot)
      @service = Service.new(@agent, daemon)
    end

    def run(params)
      @service.run
    end

    def start(params)
      @service.start @options[:write]
    end

    def stop(params)
      @service.stop @options[:write]
    end

    def restart(params)
      @service.restart
    end

    def status(params)
      @service.status
    end

    def init(params)
      @config.init *params
    end

    def add(params)
      @config.add *params
    end

    def remove(params)
      @config.remove *params
    end

    def delete(params)
      remove(params)
    end

    def confirm(params)
      confirm_flights(@config.unconfirmed)
    end

    def reconfirm(params)
      confirm_flights(@config.unconfirmed + @config.upcoming)
    end

    def checkin(params)
      groups = @config.upcoming.group_by { |flight| { :conf => flight.conf, :number => flight.number } }

      groups.values.each do |flights|
        flight = flights[0]
        name = flight.full_name
        len = flights.length
        name += " (and #{len - 1} other passenger#{len > 2 ? 's' : ''})" if len > 1
        print "Checking in #{flight.confirmation_number} (SW#{flight.number}) for #{name}... "
        if flight.checked_in?
          puts "#{flights.map(&:seat).join(', ')}"
        else
          checked_in_flights = @agent.checkin(flights)
          if checked_in_flights.nil?
            puts 'not available'
          elsif checked_in_flights.empty?
            puts 'unable to check in at this time'
          else
            puts checked_in_flights.map(&:seat).join(', ')
          end
        end
      end
    end

    def resend(params)
      groups = @config.checked_in.group_by { |flight| { :conf => flight.conf, :number => flight.number } }
      groups.values.each do |flights|
        flight = flights[0]
        name = flight.full_name
        len = flights.length
        name += " (and #{len - 1} other passenger#{len > 2 ? 's' : ''})" if len > 1
        print "Re-sending #{flight.confirmation_number} (SW#{flight.number}) to #{name}... "
        sent = @agent.resend flights
        puts( sent ? 'sent' : 'not sent' )
      end

    end

    def list(params)
      puts 'Upcoming Southwest flights:'
      puts @config.list :verbose => @options[:verbose]
    end

    def history(params)
      puts 'Previous Southwest flights:'
      puts @config.history :verbose => @options[:verbose]
    end

    def prune(params)
      n = @config.prune
      puts "Removed #{n} flight#{n == 1 ? '' : 's'}."
    end

    def test(params)
      p Southy::Airport.all.map(&:timezone).uniq
    end

    private

    def check_options
      if @options[:write]
        unless RUBY_PLATFORM =~ /darwin/
          puts "The -w option is only implemented for OS X.  That option will be ignored."
          @options[:write] = false
        end
      end
    end

    def confirm_flights(to_confirm)
      to_confirm.uniq {|f| f.confirmation_number}.each do |flight|
        print "Confirming #{flight.confirmation_number} for #{flight.full_name}... "
        response = @agent.confirm(flight)
        if response[:error]
          puts response[:error]
        else
          puts "success"
        end
      end
    end

  end
end
