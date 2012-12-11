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

      bot.add_command( :syntax => 'list mine', :regex => /^list mine$/ ) do |sender, message|
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
      flights = @config.filter @config.upcoming + @config.unconfirmed, filter
      return 'no flights found' if flights.empty?

      groups = flights.group_by { |flight| { :conf => flight.conf, :number => flight.number } }
      out = []
      groups.values.sort_by {|g| g[0].depart_date }.each do |group|
        f = group.first
        depart = ::Southy::Flight.local_date_time(f.depart_date, f.depart_code).strftime '%F %l:%M%P'
        info = "#{f.conf} - SW#{f.number} : #{depart} #{f.depart_code} -> #{f.arrive_code}"
        #info << " #{f.full_name}" if group.length == 1
        out << info
        if group.length > 0
          passengers = group.map(&:full_name).sort
          passengers.each_slice(4) do |slice|
            out << "     " + slice.join(', ')
          end
        end
        out << ''
      end
      out.join "\n"
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
