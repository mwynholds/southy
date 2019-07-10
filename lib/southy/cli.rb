module Southy

  class CLI
    def initialize(opts)
      @options = { :verbose => false }.merge opts

      @config = Config.new
      @agent = TravelAgent.new(@config)
      slackbot = Slackbot.new(@config, @agent)
      @agent.slackbot = slackbot  # ugly
      @service = Service.new(@config, @agent, slackbot)
    end

    def run(params)
      @service.run
    end

    def rundebug(params)
      Debug.debug = true
      run params
    end

    def add(params)
      if Bound.for_reservation(params[0]).length > 0
        puts "That reservation already exists.  Try 'southy reconfirm #{params[0]}'"
        return
      end

      reservation = confirm_reservation(*params)
      puts Reservation.list(reservation&.bounds)
    end

    def remove(params)
      deleted = Reservation.where(confirmation_number: params).destroy_all
      puts "Removed #{deleted.length} reservation(s) - #{deleted.map(&:conf).join(', ')}"
    end

    def delete(params)
      remove(params)
    end

    def reconfirm(params)
      reservations = params.length > 0 ? Reservation.where(confirmation_number: params[0]) : Reservation.upcoming
      reservations = confirm_reservations reservations
      puts Reservation.list reservations.map(&:bounds).flatten
    end

    def checkin(params)
      reservations = params.length > 0 ? Reservation.where(confirmation_number: params[0]) : Reservation.upcoming
      bounds   = reservations.map(&:bounds).flatten.sort_by(&:departure_time)
      max_pass = reservations.map(&:passengers_ident).map(&:length).max
      bounds.each do |b|
        r      = b.reservation
        fnum   = sprintf "%-8s", "(SW#{b.flights.first})"
        pident = sprintf "%-#{max_pass}s", r.passengers_ident
        print "Checking in #{r.conf} #{fnum} for #{pident} ... "
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
      puts Reservation.list reservations.map(&:bounds).flatten
    end

    def list(params)
      puts 'Upcoming Southwest flights:'
      puts Reservation.list Bound.upcoming
    end

    def history(params)
      puts 'Previous Southwest flights:'
      puts Reservation.list Bound.past
    end

    def info(params)
      if params.length == 0
        puts 'No confirmation number provided'
        return
      end

      reservation = Reservation.where(confirmation_number: params[0]).first
      unless reservation
        puts 'No reservation found'
        return
      end

      puts reservation.info
    end

    private

    def confirm_reservation(conf, first, last, email = nil)
      print "Confirming #{conf} for #{first} #{last}... "
      begin
        reservation, is_new = @agent.confirm conf, first, last, email, @options[:force]
        puts is_new ? "success" : "no changes"
      rescue SouthyException => e
        puts e.message
      end

      reservation
    end

    def confirm_reservations(reservations)
      reservations.sort_by { |r| r.bounds.first.departure_time }.map do |r|
        confirm_reservation r.conf, r.first_name, r.last_name, r.email
      end.compact
    end

  end
end
