module Southy

  class CLI
    def initialize(opts)
      @options = { :verbose => false }.merge opts

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
      puts Reservation.list [reservation].compact
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
      reservations = params.length > 0 ? Reservation.where(confirmation_number: params[0]) : Reservation.upcoming
      bounds = reservations.map(&:bounds).flatten.sort_by(&:departure_time)
      bounds.each do |b|
        r = b.reservation
        print "Checking in #{r.conf} (SW#{b.flights.first}) for #{r.passengers_ident} ... "
        begin
          checked_in = @agent.checkin b
          puts checked_in ? b.seats_ident : "unable to check in"
        rescue SouthyException => e
          puts e.message
        end
      end
    end

    def checkout(params)
      reservations = params.length > 0 ? Reservation.where(confirmation_number: params[0]) : Reservation.upcoming
      @agent.checkout reservations
      puts Reservation.list reservations
    end

    def list(params)
      puts 'Upcoming Southwest flights:'
      puts Reservation.list Reservation.upcoming
    end

    def history(params)
      puts 'Previous Southwest flights:'
      puts Reservation.list Reservation.past
    end

    private

    def confirm_reservation(conf, first, last, email = nil)
      @service.pause

      print "Confirming #{conf} for #{first} #{last}... "
      begin
        reservation, is_new = @agent.confirm conf, first, last, email
        puts is_new ? "success" : "no changes"
      rescue SouthyException => e
        puts e.message
      rescue Exception => e
        p e
      ensure
        @service.resume
      end

      reservation
    end

    def confirm_reservations(reservations)
      reservations.each do |r|
        confirm_reservation r.conf, r.first_name, r.last_name, r.email
      end
    end

  end
end
