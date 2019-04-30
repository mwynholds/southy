require 'slack-ruby-client'
require 'set'

module Southy
  class Slackbot
    def initialize(config, travel_agent, service)
      @config = config
      @agent = travel_agent
      @service = service
      @restarts = []
      @channels = Set.new

      @conversions = {
        'Yasmine Molavi' => [ 'Yasaman', 'Molavi Vassei' ]
      }

      Slack.configure do |slack_cfg|
        slack_cfg.token = @config.slack_api_token
      end

    end

    def run
      @webclient = Slack::Web::Client.new
      auth = @webclient.auth_test
      if auth['ok']
        puts "Slackbot is active!"
        @config.log "Slackbot is active!"
        @config.log "Accepting channels: #{@config.slack_accept_channels}" if @config.slack_accept_channels.length > 0
        @config.log "Ignoring channels: #{@config.slack_reject_channels}" if @config.slack_reject_channels.length > 0
      else
        @config.log "Slackbot is doomed :-("
        return
      end

      client = Slack::RealTime::Client.new

      client.on :message do |data|
        next if data['user'] == 'U0HM6QX8Q' # this is Mr. Southy!
        next unless data['text']
        tokens = data['text'].split ' '
        channel = data['channel']
        next unless tokens.length > 0
        next unless tokens[0].downcase == 'southy'
        next if @config.slack_accept_channels.length > 0 and ! @config.slack_accept_channels.index(channel)
        next if @config.slack_reject_channels.index channel
        message = Southy::Message.new client, channel
        message.type
        @channels << channel
        ( help(data, [], message) and next ) unless tokens[1]
        method = tokens[1].downcase
        args = tokens[2..-1]
        method = "#{method}_all" if args == [ 'all' ]
        send method, data, args, message
      end

      client.start!
    rescue => e
      @config.log "An error ocurring inside the Slackbot", e
      @restarts << Time.new
      @restarts.shift while (@restarts.length > 3)
      if @restarts.length == 3 and ( Time.new - @restarts.first < 30 )
        @config.log "Too many errors.  Not restarting anymore."
        client.on :hello do
          @channels.each do |channel|
            client.message channel: channel, text: "Oh no... I have died!  Please make me live again @mike"
          end
          client.stop!
        end
        client.start!
      else
        run
      end
    end

    def method_missing(name, *args)
      @config.log "No method found for: #{name}"
      @config.log args[0]
    end

    def user_profile(data)
      id = data['user']
      res = @webclient.users_info user: id
      return {} unless res['ok']
      profile = res['user']['profile']
      first = profile['first_name']
      last = profile['last_name']
      converted = @conversions["#{first} #{last}"]
      if converted
        first = converted[0]
        last = converted[1]
      end
      { id: id, first_name: first, last_name: last, full_name: "#{first} #{last}", email: profile['email'] }
    end

    def help(data, args, message)
      message.reply "Hello, I am Southy.  I can do the following things:"
      message.reply <<EOM
```
southy help              Show this message
southy hello             Say hello to me!
southy whatsup           Show me ALL the flights upcoming
southy list              Show me what flights I have upcoming
southy history           Show me what flights I had in the past
southy add <conf>        Add this flight to Southy
southy remove <conf>     Remove this flight from Southy
southy reconfirm         Reconfirm your flights, if you have changed flight info

<conf> = Your flight confirmation number and optionally contact info, for example:
         southy add RB7L6K     <-- uses your name and email from Slack
         southy add RB7L6K Joey Shabadoo joey@snpp.com
```
EOM
    end

    def blowup(data, args, message)
      message.reply "Tick... tick... tick... BOOM!   Goodbye."
      EM.next_tick do
        raise "kablammo!"
      end
    end

    def hello(data, args, message)
      profile = user_profile data
      if profile[:first_name] and profile[:last_name] and profile[:email]
        message.reply "Hello #{profile[:first_name]}!  You are all set to use Southy."
        message.reply "I will use this information when looking up your flights:"
        message.reply <<EOM
```
name:  #{profile[:first_name]} #{profile[:last_name]}
email: #{profile[:email]}
```
EOM
      else
        message.reply "Hello.  You are not set up yet to use Southy.  You need to fill in your first name, last name and email in your Slack profile."
      end
    end

    def print_flights(flights, message)
      out = '```'
      if flights.length > 0
        out += Southy::Flight.sprint flights, short: true
      else
        out += 'No upcoming flights.'
      end
      out += '```'
      message.reply out
    end

    def list(data, args, message)
      profile = user_profile data
      message.reply "Upcoming Southwest flights for #{profile[:email]}:"
      message.type
      if args && args.length > 0
        flights = @config.upcoming.select { |f| f.confirmation_number.downcase == args[0].downcase }
      else
        flights = @config.upcoming.select { |f| f.email == profile[:email] || f.full_name == profile[:full_name] }
      end
      print_flights flights, message
    end

    def list_all(data, args, message)
      message.reply "Upcoming Southwest flights:"
      message.type
      flights = @config.upcoming
      print_flights flights, message
    end

    def whatup(data, args, message)
      whatsup data, args, message
    end

    def whatsup(data, args, message)
      list_all data, args, message
      message.reply "```You can type 'southy help' to see more commands```"
    end

    def history(data, args, message)
      profile = user_profile data
      message.reply "Previous Southwest flights for #{profile[:email]}:"
      message.type
      flights = @config.past.select { |f| f.email == profile[:email] }
      flights.each_slice(30) do |slice|
        print_flights slice, message
      end
    end

    def history_all(data, args, message)
      message.reply "Previous Southwest flights:"
      message.type
      flights = @config.past
      print_flights flights, message
    end

    def add(data, args, message)
      args.tap do |(conf, fname, lname, email)|
        return ( message.reply "You didn't enter a confirmation number!" ) unless conf
        profile = user_profile data
        unless fname and lname
          fname = profile[:first_name]
          lname = profile[:last_name]
        end
        unless email
          email = profile[:email]
        end
        if email && match = email.match(/^<mailto:(.*)\|/)
          email = match.captures[0]
        end

        begin
          @service.pause
          result = @config.add conf, fname, lname, email
          if result && result[:error]
            message.reply result[:error]
            return
          end

          flights = @config.find conf
          result = @agent.confirm flights[0]
          if result && result[:error]
            message.reply "Could not confirm flights: #{result[:reason]}"
            return
          end
        ensure
          @service.resume
        end

        flights = @config.upcoming.select { |f| f.conf.downcase == conf.downcase }
        print_flights flights, message
      end
    end

    def remove(data, args, message)
      args.tap do |(conf)|
        return ( message.reply "You didn't enter a confirmation number!" ) unless conf
        @config.remove conf
        list data, '', message
      end
    end

    def reconfirm(data, args, message)
      profile = user_profile data
      message.reply "Reconfirming Southwest flights for #{profile[:email]}:"
      message.type
      flights = @config.upcoming.select { |f| f.email == profile[:email] }
      flights.uniq { |f| f.conf }.each do |f|
        @agent.confirm f
        message.type
      end
      flights = @config.upcoming.select { |f| f.email == profile[:email] }
      print_flights flights, message
    end
  end
end
