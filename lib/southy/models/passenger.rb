module Southy
  class Passenger < ActiveRecord::Base
    validates  :name, presence: true

    belongs_to :reservation
    has_many   :seats,       dependent: :destroy, autosave: true

    NICKNAMES = {
      "Bill" => "William",
      "Mike" => "Michael",
    }

    def ==(other)
      name == other.name
    end

    def first_name
      name.split(' ').first
    end

    def last_name
      name.split(' ').last
    end

    def name_matches?(n)
      ns = n.split(' ')
      n.last == last_name && ( n.first.starts_with(first_name) || first_name.starts_with(n.first) )
    end

    def first_name_matches?(a, b)
      return true if a == b
      return true if a.starts_with b
      return true if b.starts_with a
      return true if NICKNAMES.any? { |nick, name| (nick == a && name == b) ||
                                                   (nick == b && name == a) }
      false
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

    def seats_ident_for(bound)
      seats_for(bound).map { |s| s.ident }.join(", ")
    end

    def checked_in_for?(bound)
      seats_for(bound).length == bound.flights.length
    end
  end
end
