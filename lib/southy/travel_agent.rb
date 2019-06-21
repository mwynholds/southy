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

      reservation = monkey.lookup conf, first, last
      reservation.email = email

      if ! Reservation.exists? reservation
        reservation.save!
        return reservation, true
      elsif Reservation.matches? reservation
        return Reservation.where(confirmation_number: conf).first, false
      else
        Reservation.where(confirmation_number: conf).destroy_all
        reservation.save!
        @slackbot.notify_reconfirmed reservation
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

      checked_in = monkey.checkin bound.reservation
      checked_in.save!
      @mailer.send_email bound
      @slackbot.notify_checked_in bound
      checked_in
    end

    def checkout(reservations)
      reservations.each do |r|
        r.checkout
        r.save!
      end
    end
  end
end
