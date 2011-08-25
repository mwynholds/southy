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
      @service = Service.new daemon
    end

    def run(params)
      @service.run
    end

    def start(params)
      puts "Starting..."
    end

    def stop(params)
      puts "Stopping..."
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
  end
end
