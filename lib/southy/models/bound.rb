module Southy
  class Bound < ActiveRecord::Base
    validates  :departure_time, presence: true
    validates  :departure_code, presence: true
    validates  :arrival_time, presence: true
    validates  :arrival_code, presence: true

    belongs_to :reservation
    has_many   :stops, dependent: :destroy, autosave: true
    has_many   :seats, dependent: :destroy, autosave: true

    scope    :upcoming, -> { where("arrival_time >= '#{Date.today}'").order(:departure_time) }
    scope    :past,     -> { where("arrival_time <= '#{Date.today}'").order(:departure_time) }

    def departure_airport
      Airport.lookup departure_code
    end

    def arrival_airport
      Airport.lookup arrival_code
    end

    def local_departure_time
      departure_airport.local_time departure_time
    end

    def local_arrival_time
      arrival_airport.local_time arrival_time
    end

    def passengers
      reservation.passengers
    end

    def ident
      "#{reservation.ident} - SW#{flights.first}"
    end

    def has_seats?
      seats && seats.length > 0
    end

    def seats_ident
      reservation.passengers.map do |passenger|
        reservation.seats_for(passenger, self).map(&:ident).first
      end.compact.join(', ')
    end

    def checked_in?
      reservation.passengers.any? { |p| p.checked_in_for? self }
    end

    def checkin_available?
      return false if departure_time < DateTime.now    # oops you missed your flight
      DateTime.now >= departure_time - (60*60*24) - 1  # start trying 1 second early!
    end

    def checkin_time?
      return false unless checkin_available?
      now = DateTime.now
      checkin_time = departure_time - (60*60*24)
      # try hard for one minute
      now >= checkin_time - 3 && now <= checkin_time + 60
    end

    def late_checkin_time?
      return false unless checkin_available?
      now = DateTime.now
      # then keep trying every hour for one minute
      now.min == 0
    end

    def ==(other)
      departure_time == other.departure_time &&
        departure_code == other.departure_code &&
        arrival_time == other.arrival_time &&
        arrival_code == other.arrival_code
    end
  end
end
