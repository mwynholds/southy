module Southy
  class Bot

    def initialize()
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

      bot.add_command( :syntax => 'list', :regex => /^list$/ ) do
        list
      end

      bot.add_command( :syntax => 'list mine', :regex => /^list mine$/ ) do |sender|
        list sender
      end

      bot.add_command( :syntax => 'search', :regex => /^list (.*)$/ ) do |sender, message|
        list message
      end

      bot.add_command( :syntax => 'add', :regex => /^add (.*)$/ ) do |sender, message|
        conf, first, last, email = message.split
        @config.add conf, first, last, email
        sleep 3
        list conf
      end

      bot.add_command( :syntax => 'remove', :regex => /^remove (.*)$/ ) do |sender, message|
        @config.remove message
        list
      end

      bot
    end

    def list(filter = nil)
      @config.reload
      capture { @config.list :filter => filter }
    end

    def start
      @bot.connect
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
