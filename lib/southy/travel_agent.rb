module Southy
  class TravelAgent

    attr_reader :config

    def initialize(config, opts = {})
      @is_test = opts[:test] == true
      @config = config
      @mailer = Southy::Mailer.new config
    end

    def monkey
      @is_test ? Southy::TestMonkey.new : Southy::Monkey.new(config)
    end

    def confirm(conf, first, last, email = nil)
      flight_info = "#{conf} (#{first} #{last})"

      begin
        reservation = monkey.lookup conf, first, last
      rescue SouthyException => e
        @config.log "Flight not confirmed due to '#{e.message}' : #{flight_info}"
        raise e
      end

      if Reservation.matches? reservation
        @config.log "No changes to #{reservation.ident}"
        return reservation, false
      else
        reservation.save!
        @config.log "Confirmed #{reservation.ident}"
        return reservation, true
      end
    end

    def checkin(flights)
      flight = flights[0]
      return {} unless flight.checkin_available?

      name = flight.full_name
      len = flights.length
      name += " (and #{len - 1} other passenger#{len > 2 ? 's' : ''})" if len > 1

      info = monkey.checkin(flights)
      checked_in_flights = info[:flights]
      if checked_in_flights && checked_in_flights.size > 0
        checked_in_flights.each do |checked_in_flight|
          @config.checkin checked_in_flight
        end
        @mailer.send_email checked_in_flights
        seats = checked_in_flights.map(&:seat).join(', ')
        @config.log "Checked in #{flight.conf} for #{name} - #{seats}"
      else
        @config.log "Unable to check in #{flight.conf} for #{name}"
      end
      info
    end

    def checkout(flights)
      flights.each do |flight|
        @config.checkout flight
      end
    end

    def resend(flights)
      return false unless flights[0].checked_in?

      @mailer.send_email flights
    end
  end
end
