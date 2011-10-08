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
      @config.upcoming.each do |flight|
        print "Checking in #{flight.confirmation_number} (SW#{flight.number}) for #{flight.full_name}... "
        flights = @agent.checkin(flight)
        if flights.nil?
          puts 'not available'
        else
          puts flights.map(&:seat).join(', ')
        end
      end
    end

    def list(params)
      @config.list :verbose => @options[:verbose]
    end

    def history(params)
      @config.history :verbose => @options[:verbose]
    end

    def test(params)
      Southy::Airport.dump
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
