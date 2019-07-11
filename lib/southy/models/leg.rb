module Southy
  class Leg
    attr_accessor :num, :departure, :arrival

    def departure_code
      @departure.is_a?(Bound) ? @departure.departure_code : @departure.code
    end

    def departure_city
      @departure.is_a?(Bound) ? @departure.departure_city : @departure.city
    end

    def departure_state
      @departure.is_a?(Bound) ? @departure.departure_state : @departure.state
    end

    def departure_time
      @departure.departure_time
    end

    def departure_ident
      "#{departure_city}, #{departure_state} (#{departure_code})"
    end

    def departure_clock_time
      departure_time.strftime("%l:%M%P").strip
    end

    def arrival_code
      @arrival.is_a?(Bound) ? @arrival.arrival_code : @arrival.code
    end

    def arrival_city
      @arrival.is_a?(Bound) ? @arrival.arrival_city : @arrival.city
    end

    def arrival_state
      @arrival.is_a?(Bound) ? @arrival.arrival_state : @departure.state
    end

    def arrival_time
      @arrival.arrival_time
    end

    def arrival_ident
      "#{arrival_city}, #{arrival_state} (#{arrival_code})"
    end

    def arrival_clock_time
      arrival_time.strftime("%l:%M%P").strip
    end

    def duration
      pretty_duration(arrival_time - departure_time)
    end

    def layover_duration_until(next_leg)
      pretty_duraction(next_leg.departure_time - arrival_time)
    end

    def pretty_duration(seconds)
      minutes = seconds.div 60
      hours   = minutes.div 60
      "#{hours}hr #{minutes - hours * 60}min"
    end
  end
end
