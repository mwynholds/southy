module Southy

  class CLI
    def initialize(opts)
      @options = { :verbose => false, :write => false }.merge opts
      check_options

      @config = Config.new
      @agent = TravelAgent.new(@config)
      daemon = Daemon.new(@agent)
      @service = Service.new(@agent, daemon)
      slackbot = Slackbot.new(@config, @agent, @service)
      daemon.slackbot = slackbot  # TODO: this is circular and ugly :-(
      @mailer = Mailer.new(@config)
    end

    def run(params)
      @service.run
    end

    def rundebug(params)
      Debug.debug = true
      run params
    end

    def start(params)
      @service.start @options[:write]
    end

    def startdebug(params)
      Debug.debug = true
      start params
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

    def add(params)
      if Reservation.where(confirmation_number: params[0]).length > 0
        puts "That reservation already exists.  Try 'southy reconfirm #{params[0]}'"
        return
      end

      reservation = confirm_reservation *params
      puts Reservation.list [reservation]
    end

    def remove(params)
      deleted = Reservation.where(confirmation_number: params).destroy_all
      l = deleted.length
      puts "Removed #{deleted.length} reservation(s) - #{deleted.map(&:conf).join(', ')}"
    end

    def delete(params)
      remove(params)
    end

    def reconfirm(params)
      reservations = params.length > 0 ? Reservation.where(confirmation_number: params[0]) : Reservation.upcoming
      reservations = confirm_reservations reservations
      puts Reservation.list reservations
    end

    def checkin(params)
      input = params.length > 0 ? @config.find(params[0]) : @config.upcoming
      groups = input.group_by { |flight| { :conf => flight.conf, :number => flight.number } }

      groups.values.each do |flights|
        flight = flights[0]
        name = flight.full_name
        len = flights.length
        name += " (and #{len - 1} other passenger#{len > 2 ? 's' : ''})" if len > 1
        print "Checking in #{flight.confirmation_number} (SW#{flight.number}) for #{name}... "
        if flight.checked_in?
          puts "#{flights.map(&:seat).join(', ')}"
        else
          response = @agent.checkin(flights)
          if response[:error]
            puts "#{response[:error]} (#{response[:reason]})"
          else
            checked_in_flights = response[:flights]
            if checked_in_flights.nil?
              puts 'not available'
            elsif checked_in_flights.empty?
              puts 'unable to check in at this time'
            else
              puts checked_in_flights.map(&:seat).join(', ')
            end
          end
        end
      end
    end

    def checkout(params)
      input = params.length > 0 ? @config.find(params[0]) : @config.upcoming
      @agent.checkout input
      puts @config.list :verbose => @options[:verbose], :filter => ( params[0] )
    end

    def resend(params)
      groups = @config.checked_in.group_by { |flight| { :conf => flight.conf, :number => flight.number } }
      groups.values.each do |flights|
        flight = flights[0]
        name = flight.full_name
        len = flights.length
        name += " (and #{len - 1} other passenger#{len > 2 ? 's' : ''})" if len > 1
        print "Re-sending #{flight.confirmation_number} (SW#{flight.number}) to #{name}... "
        sent = @agent.resend flights
        puts( sent ? 'sent' : 'not sent' )
      end

    end

    def list(params)
      puts 'Upcoming Southwest flights:'
      puts Reservation.list Reservation.upcoming
    end

    def history(params)
      puts 'Previous Southwest flights:'
      puts @config.history :verbose => @options[:verbose]
    end

    def prune(params)
      n = @config.prune
      puts "Removed #{n} flight#{n == 1 ? '' : 's'}."
    end

    def test(params)
      p Airport.all.map(&:timezone).uniq
    end

    def email(params)
      ( return puts "No email provided" ) unless params.length > 0
      @mailer.send_test_email params[0]
      puts "Sent email to #{params[0]}"
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

    def confirm_reservation(conf, first, last, email = nil)
      @service.pause

      print "Confirming #{conf} for #{first} #{last}... "
      begin
        reservation, is_new = @agent.confirm conf, first, last, email
        puts is_new ? "success" : "no changes"
      rescue SouthyException => e
        puts e.message
      end

      @service.resume
      reservation
    end

    def confirm_reservations(reservations)
      reservations.each do |r|
        confirm_reservation r.conf, r.passengers.first.first_name, r.passengers.first.last_name, r.email
      end
    end

  end
end
