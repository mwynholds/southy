module Southy
  require 'southy/version'
  require 'southy/helpers'
  require 'southy/monkey'
  require 'southy/service'
  require 'southy/config'
  require 'southy/daemon'
  require 'southy/checkin_document'
  require 'southy/flight'
  require 'southy/travel_agent'

  class CLI
    def initialize(opts)
      @options = { :write => false }.merge opts
      check_options

      @config = Config.new
      monkey = TestMonkey.new
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

    def confirm(params)
      @config.unconfirmed.uniq {|f| f.confirmation_number}.each do |flight|
        print "Confirming #{flight.confirmation_number} for #{flight.full_name}... "
        if @agent.confirm(flight)
          puts "success"
        else
          puts "failure"
        end
      end
    end

    def checkin(params)
      @config.upcoming.each do |flight|
        print "Checking in #{flight.confirmation_number}... "
        flights = @agent.checkin(flight)
        if flights.nil?
          puts 'not available'
        else
          puts flights.map(&:seat).join(', ')
        end
      end
    end

    def list(params)
      @config.list
    end

    def history(params)
      @config.history
    end

    def test(params)
      flights = @agent.monkey.lookup('WZAR5K', 'Madeleine', 'Wynholds')
      #flights += @monkey.lookup('WQNR57', 'Michael', 'Wynholds')
      flights.each { |f| puts f }
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
  end
end
