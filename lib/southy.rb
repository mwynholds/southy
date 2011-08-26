module Southy
  VERSION = "0.0.1"

  require 'southy/monkey'
  require 'southy/service'
  require 'southy/config'
  require 'southy/daemon'
  require 'southy/checkin_document'
  require 'southy/flight'

  class CLI
    def initialize
      @monkey = Monkey.new
      @config = Config.new
      daemon = Daemon.new @config, @monkey
      @service = Service.new @config, daemon
    end

    def run(params)
      @service.run
    end

    def start(params)
      @service.start
    end

    def stop(params)
      @service.stop
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

    def list(params)
      @config.list
    end

    def history(params)
      @config.history
    end

    def test(params)
      flights = @monkey.lookup('WZAR5K', 'Madeleine', 'Wynholds')
      flights += @monkey.lookup('WQNR57', 'Michael', 'Wynholds')
      flights.each { |f| puts f }
    end
  end
end
