module Southy
  class Bound < ActiveRecord::Base
    validates  :departure_time, presence: true
    validates  :departure_code, presence: true
    validates  :arrival_time, presence: true
    validates  :arrival_code, presence: true

    belongs_to :reservation
    has_many   :stops, dependent: :destroy

    def departure_airport
      Airport.lookup departure_code
    end

    def arrival_airport
      Airport.lookup arrival_code
    end

    def ==(other)
      departure_time == other.departure_time &&
        departure_code == other.departure_code &&
        arrival_time == other.arrival_time &&
        arrival_code == other.arrival_code
    end
  end
end
