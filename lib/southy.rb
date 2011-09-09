module Southy
  require 'southy/version'
  require 'southy/helpers'
  require 'southy/monkey'
  require 'southy/service'
  require 'southy/config'
  require 'southy/daemon'
  require 'southy/checkin_document'
  require 'southy/flight'

  class CLI
    def initialize(opts)
      @options = { :write => false }.merge opts
      check_options

      @monkey = Monkey.new
      @config = Config.new
      daemon = Daemon.new @config, @monkey
      @service = Service.new @config, daemon
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
      @config.upcoming.uniq {|f| f.confirmation_number}.each do |flight|

        print "Confirming #{flight.confirmation_number} for #{flight.full_name}... "
        flights = @monkey.lookup(flight.confirmation_number, flight.first_name, flight.last_name)
        if flights.length > 0
          @config.remove flight.confirmation_number
          flights.each do |f|
            f.email = flight.email
            @config.confirm f
          end
          puts "success"
        else
          puts "failure"
        end
      end
    end

    def checkin(params)
      @config.upcoming.each do |flight|
        print "Checking in #{flight.confirmation_number}... "
        if flight.checkin_available?
          docs = @monkey.checkin flight
          if docs.nil?
            puts "failed"
          else
            puts docs.map(&:seat).join(', ')
          end
        else
          puts "not available"
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
      flights = @monkey.lookup('WZAR5K', 'Madeleine', 'Wynholds')
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
