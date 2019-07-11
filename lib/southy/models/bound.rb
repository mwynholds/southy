module Southy
  class Bound < ActiveRecord::Base
    validates  :departure_time, presence: true
    validates  :departure_code, presence: true
    validates  :arrival_time, presence: true
    validates  :arrival_code, presence: true

    belongs_to :reservation
    has_many   :stops, dependent: :destroy, autosave: true
    has_many   :seats, dependent: :destroy, autosave: true

    scope :upcoming, -> { where("departure_time >  '#{DateTime.now}'").order(:departure_time) }
    scope :past,     -> { where("departure_time <= '#{DateTime.now}'").order(:departure_time) }

    def self.for_reservation(conf)
      select { |b| b.reservation.conf == conf }
    end

    def self.for_person(email, name)
      select { |b| b.reservation.person_matches? email, name }
    end

    def departure_airport
      Airport.lookup departure_code
    end

    def arrival_airport
      Airport.lookup arrival_code
    end

    def departure_ident
      "#{departure_city}, #{departure_state} (#{departure_code})"
    end

    def arrival_ident
      "#{arrival_city}, #{arrival_state} (#{arrival_code})"
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

    def ready_for_checkin?
      return false if checked_in?
      return false unless checkin_available?
      return true  if reservation.last_checkin_attempt == nil
      checkin_time? || late_checkin_time?
    end

    def checked_in?
      reservation.passengers.any? { |p| p.checked_in_for? self }
    end

    def checkin_available?
      return false if departure_time < DateTime.now    # oops you missed your flight
      DateTime.now >= departure_time - (60*60*24) + 3  # -1 for 1 second early, +1 for one second late
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

    def get_legs
      legs = [ Leg.new ]

      legs.first.num = flights.first
      legs.first.departure = self

      stops.each_with_index do |stop, i|
        legs.last.arrival = stop
        legs << Leg.new
        legs.last.num = flights[i+1]
        legs.last.departure = stop
      end

      legs.last.arrival = self
      legs
    end

    def info
      all      = reservation.bounds.map(&:get_legs).flatten
      n_max    = all.map(&:num).map(&:length).max
      d_max    = all.map(&:departure_ident).map(&:length).max
      a_max    = all.map(&:arrival_ident).map(&:length).max

      legs     = get_legs
      layovers = legs.each_cons(2).map { |(l1, l2)| l1.layover_duration_until(l2) }

      lines = legs.map do |leg|
        sprintf "SW%-#{n_max}s  %-#{d_max}s  ->  %-#{a_max}s\n" +
                "  %-#{n_max}s  %-#{d_max}s      %-#{a_max}s   %s",
                leg.num, leg.departure_ident, leg.arrival_ident,
                "", leg.departure_clock_time, leg.arrival_clock_time, leg.duration
      end.zip(layovers).flatten.compact

      date   = departure_time.strftime "%B %-d, %Y"
      header = "#{bound_type} - #{date}"
      hr     = "-" * header.length

      header + "\n" + hr + "\n" + lines.join("\n")
    end
  end
end
