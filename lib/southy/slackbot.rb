require 'slack-ruby-client'

module Southy
  class Slackbot
    def initialize(config, travel_agent)
      @config = config
      @agent = travel_agent

      Slack.configure do |slack_cfg|
        slack_cfg.token = @config.slack_api_token
      end

    end

    def run
      @webclient = Slack::Web::Client.new
      auth = @webclient.auth_test
      if auth['ok']
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
        send_msg = Proc.new { |msg| client.message channel: channel, text: msg }
        method = tokens[1]
        args = tokens[2..-1]
        method = "#{method}_all" if args == [ 'all' ]
        ( help(data, [], &send_msg) and next ) unless method
        send method, data, args, &send_msg
      end

      client.start!
    rescue => e
      @config.log "An error ocurring inside the Slackbot", e
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
      { id: id, first_name: profile['first_name'], last_name: profile['last_name'], email: profile['email'] }
    end

    def help(data, args, &send)
      send.call "Hello, I am Southy.  I can do the following things:"
      send.call <<EOM
```
southy help              Show this message
southy hello             Say hello to me!
southy list              Show me what flights I have upcoming
southy history           Show me what flights I had in the past
southy add <conf>        Add this flight to Southy
southy remove <conf>     Remove this flight from Southy

<conf> = Your flight confirmation number, eg: RB7L6K
```
EOM
    end

    def hello(data, args, &send)
      profile = user_profile data
      if profile[:first_name] and profile[:last_name] and profile[:email]
        send.call "Hello #{profile[:first_name]}!  You are all set to use Southy."
        send.call "I will use this information when looking up your flights:"
        send.call <<EOM
```
name:  #{profile[:first_name]} #{profile[:last_name]}
email: #{profile[:email]}
```
EOM
      else
        send.call "Hello.  You are not set up yet to use Southy.  You need to fill in your first name, last name and email in your Slack profile."
      end
    end

    def print_flights(flights, &send)
      out = '```'
      if flights.length > 0
        out += Southy::Flight.sprint flights, short: true
      else
        out += 'No upcoming flights.'
      end
      out += '```'
      send.call out
    end

    def list(data, args, &send)
      profile = user_profile data
      send.call "Upcoming Southwest flights for #{profile[:email]}:"
      flights = @config.upcoming.select { |f| f.email == profile[:email] }
      print_flights flights, &send
    end

    def list_all(data, args, &send)
      send.call "Upcoming Southwest flights:"
      flights = @config.upcoming
      print_flights flights, &send
    end

    def history(data, args, &send)
      profile = user_profile data
      send.call "Previous Southwest flights for #{profile[:email]}:"
      flights = @config.past.select { |f| f.email == profile[:email] }
      print_flights flights, &send
    end

    def history_all(data, args, &send)
      send.call "Previous Southwest flights:"
      flights = @config.past
      print_flights flights, &send
    end

    def add(data, args, &send)
      args.tap do |(conf, fname, lname, email)|
        unless fname and lname
          profile = user_profile data
          fname = profile[:first_name]
          lname = profile[:last_name]
          email = profile[:email]
        end
        return ( send.call "You didn't enter a confirmation number!" ) unless conf
        if match = email.match(/^<mailto:(.*)\|/)
          email = match.captures[0]
        end
        @config.add conf, fname, lname, email
        sleep 3
        list data, '', &send
      end
    end

    def remove(data, args, &send)
      args.tap do |(conf)|
        return ( send.call "You didn't enter a confirmation number!" ) unless conf
        @config.remove conf
        list data, '', &send
      end
    end
  end
end
