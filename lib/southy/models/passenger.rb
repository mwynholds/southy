module Southy
  class Passenger < ActiveRecord::Base
    validates  :name, presence: true

    belongs_to :reservation
    has_many   :seats,       dependent: :destroy, autosave: true

    def ==(other)
      name == other.name
    end

    def first_name
      name.split(' ').first
    end

    def last_name
      name.split(' ').last
    end

    def assign_seat(seat, bound)
      existing = seats.find { |s| s.bound == bound && s.flight == seat.flight }
      if existing
        existing.group = seat.group
        existing.position = seat.position
      else
        seat.bound = bound
        seats << seat
      end
    end

    def seats_for(bound)
      seats.select { |s| s.bound == bound }
    end

    def checked_in_for?(bound)
      seats_for(bound).length == bound.flights.length
    end
  end
end
