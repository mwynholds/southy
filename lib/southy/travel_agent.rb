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

    def confirm(conf, first, last, email, force)
      flight_info = "#{conf} (#{first} #{last})"

      reservation = monkey.lookup conf, first, last
      reservation.email = email

      if ! Reservation.exists? reservation
        reservation.save!
        return reservation, true
      end

      matches = Reservation.matches? reservation

      if force || ! matches
        Reservation.where(confirmation_number: conf).destroy_all
        reservation.save!
        @slackbot.notify_reconfirmed reservation unless matches
        return reservation, true
      end

      return Reservation.where(confirmation_number: conf).first, false
    rescue SouthyException => e
      if e.code == 400520414  # flight canceled
        reservation = Reservation.where(confirmation_number: conf).first
        if reservation
          @slackbot.notify_canceled reservation
          reservation.destroy
        end
      end
      raise e
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

  class TestTravelAgent < TravelAgent
    def confirm(conf, first, last, email, force, opts = {})
      @monkey.json_num = opts[:json_num]
      ret = super conf, first, last, email, force
      @monkey.json_num = nil
      ret
    end
  end
end
