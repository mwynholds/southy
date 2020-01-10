module Southy
  class Passenger < ActiveRecord::Base
    validates  :name, presence: true

    belongs_to :reservation
    has_many   :seats,       dependent: :destroy, autosave: true

    NICKNAMES = {
      "Bill"  => "William",
      "Mike"  => "Michael",
      "Katie" => "Katherine",
    }

    def ==(other)
      name == other.name
    end

    def first_name
      name.split(' ').first
    end

    def last_name
      name.split(' ')[1..-1].join(' ')
    end

    def name_matches?(n)
      ns = n.split(' ')
      ns.last == last_name && ( ns.first.starts_with?(first_name) || first_name.starts_with?(ns.first) )
    end

    def search_matches?(n)
      n.downcase == last_name.downcase || n.downcase == first_name.downcase
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

    def self.possible_names(first_name, last_name)
      firsts = first_name.gsub(/-/, "").split " "
      lasts  = last_name.gsub(/-/, "").split " "
      names  = [ firsts, lasts ].flatten

      if names.length > 3
        names = names.take(1) + names.last(2)
        puts "Warning - too many name combos for #{first_name} #{last_name} - using #{names.join(' ')}"
      end

      if names.length == 3
        [ [ names[0], names.last(2).join(" ") ],
          [ names.take(2).join(" "), names[2] ] ]
      else
        [ names ]
      end
    end
  end
end
