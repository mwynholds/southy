module Southy
  class Bot

    def initialize(opts)
      @options = { :verbose => false }.merge opts
      @config = Config.new
      @bot = configure_bot
    end

    def configure_bot
      bot = ::Jabber::Bot.new(
        :name => 'Southy Bot',
        :jabber_id => 'southy@jabber.org',
        :password => '!!checkmein',
        :master => %w( mike@carbonfive.com )
      )

      bot.add_command(
        :syntax => 'list all',
        :description => 'Display upcoming flight check-ins',
        :regex => /^list all$/,
      ) do
        capture { @config.list }
      end

      bot.add_command(
        :syntax => 'list',
        :description => 'Display my upcoming flight check-ins',
        :regex => /^list$/,
      ) do |sender|
        capture { @config.list :filter => sender }
      end

      bot.add_command(
        :syntax => 'list filtered',
        :description => 'Display filtered upcoming flight check-ins',
        :regex => /^list (.*)$/,
      ) do |sender, message|
        capture { @config.list :filter => message }
      end

      bot
    end

    def start
      @bot.connect
    end

    def stop
      @bot.disconnect
    end

    def restart
      stop
      start
    end

    def capture
      out = StringIO.new
      $stdout = out
      yield
      out.string
    ensure
      $stdout = STDOUT
    end
  end
end
