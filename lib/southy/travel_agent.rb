module Southy
  class TravelAgent

    attr_reader :config
    attr_accessor :monkey

    def initialize(config)
      @config = config
      @mailer = Mailer.new config
      @monkey = Monkey.new config
    end

    def slackbot=(slackbot)
      @slackbot = slackbot
    end

    def confirm(conf, first, last, email = nil)
      flight_info = "#{conf} (#{first} #{last})"

      begin
        reservation = monkey.lookup conf, first, last
        reservation.email = email
      rescue SouthyException => e
        @config.log "Flight not confirmed due to '#{e.message}' : #{flight_info}"
        raise e
      end

      if Reservation.matches? reservation
        @config.log "No changes to #{reservation.ident}"
        return reservation, false
      else
        Reservation.where(confirmation_number: conf).destroy_all
        reservation.save!
        @config.log "Confirmed #{reservation.ident}"
        return reservation, true
      end
    end

    def checkin(bound, force: false)
      return bound.reservation if bound.checked_in?

      unless force
        raise SouthyException.new("check in not available") unless bound.checkin_available?
      end

      bound.reservation.last_checkin_attempt = DateTime.now
      bound.reservation.save!

      begin
        checked_in = monkey.checkin bound.reservation
        checked_in.save!
        @mailer.send_email bound
        @slackbot.notify_checked_in bound
        @config.log "Checked in #{bound.ident} - #{bound.seats_ident}"
        checked_in
      rescue SouthyException => e
        @config.log "Unable to check in #{bound.ident}"
        raise e
      end
    end

    def checkout(reservations)
      reservations.each do |r|
        r.checkout
        r.save!
      end
    end
  end
end
