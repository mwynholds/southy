module Southy
  require 'southy/version'
  require 'southy/helpers'
  require 'southy/monkey'
  require 'southy/service'
  require 'southy/config'
  require 'southy/daemon'
  require 'southy/flight'
  require 'southy/travel_agent'
  require 'southy/airport'

  class CLI
    def initialize(opts)
      @options = { :verbose => false, :write => false }.merge opts
      check_options

      @config = Config.new
      monkey = Monkey.new
      @agent = TravelAgent.new(@config, monkey)
      daemon = Daemon.new(@agent)
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

    def list(params)
      @config.list :verbose => @options[:verbose]
    end

    def history(params)
      @config.history :verbose => @options[:verbose]
    end

    def prune(params)
      @config.prune
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
        flights = @agent.confirm(flight)
        if flights && ! flights.empty?
          puts "success"
        else
          puts "failure"
        end
      end
    end

  end
end
