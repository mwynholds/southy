module Southy
  class Reservation < ActiveRecord::Base
    validates :confirmation_number, presence: true, uniqueness: { case_insensitive: true }
    validates :origin_code, presence: true
    validates :destination_code, presence: true

    has_many :bounds, -> { order departure_time: :asc }, dependent: :destroy, autosave: true
    has_many :passengers, dependent: :destroy, autosave: true

    scope    :upcoming, -> { joins(:bounds).where("bounds.departure_time >  ?", DateTime.now).distinct }
    scope    :past    , -> { joins(:bounds).where("bounds.departure_time <= ?", DateTime.now).distinct }

    def self.for_person(id, email, name)
      select { |r| r.person_matches? id, email, name }
    end

    def conf
      confirmation_number
    end

    def origin_airport
      Airport.lookup origin_code
    end

    def destination_airport
      Airport.lookup destination_code
    end

    def first_name
      passengers.first.first_name
    end

    def last_name
      passengers.first.last_name
    end

    def person_matches?(id, email, name)
      self.created_by == id || self.email == email || passengers.any? { |p| p.name_matches? name }
    end

    def ==(other)
      conf == other.conf &&
        origin_code == other.origin_code &&
        destination_code == other.destination_code
        bounds == other.bounds &&
        passengers == other.passengers
    end

    def passengers_ident
      l = passengers.length
      passengers.first.name + ( l == 1 ? "" : " (+#{l-1})" )
    end

    def ident
      "#{conf} (#{passengers_ident})"
    end

    def seats_ident
      bounds.sort_by(&:departure_time).map do |bound|
        bound.seats_ident
      end.join(" | ")
    end

    def seats_for(passenger, bound)
      passenger.seats_for(bound).sort do |a, b|
        bound.flights.index(a.flight) - bound.flights.index(b.flight)
      end
    end

    def seats_ident_for(passenger)
      bounds.map do |b|
        seats_for(passenger, b).map(&:ident).join(", ")
      end.reject(&:blank?).join(" / ")
    end

    def bound_for(flight)
      bounds.find { |b| b.flights.include? flight }
    end

    def checkout
      self.last_checkin_attempt = nil
      passengers.each do |passenger|
        passenger.seats.each do |seat|
          seat.mark_for_destruction
        end
      end
    end

    def info
      date_header = bounds.first.departure_local_time.strftime "%B %-d"
      city_header = "#{bounds.first.arrival_city}, #{bounds.first.arrival_state}"
      p_max       = passengers.map(&:name).map(&:length).max
      pass_list   = passengers.map { |p| sprintf "%-#{p_max}s  %s", p.name, seats_ident_for(p) }.join "\n"
      bound_list  = bounds.map(&:info).join("\n\n")
      <<-EOF
Reservation ##{conf}
#{date_header} - #{city_header}

PASSENGERS
----------
#{pass_list}

#{bound_list}
EOF
    end

    def self.exists?(reservation)
      existing = Reservation.where confirmation_number: reservation.conf
      existing && existing.length > 0
    end

    def self.matches?(reservation)
      existing = Reservation.where confirmation_number: reservation.conf
      existing && existing.first == reservation
    end

    def self.from_json(json)
      raise SouthyException.new("No inbound or outbound flights") unless json.bounds
      raise SouthyException.new("No passengers") unless json.passengers

      res = Reservation.new

      res.confirmation_number = json.confirmationNumber
      res.origin_code         = json.originAirport.code
      res.destination_code    = json.destinationAirport.code

      Airport.validate res.origin_code
      Airport.validate res.destination_code

      res.bounds = json.bounds.map do |boundJson|
        bound                 = Bound.new
        bound.bound_type      = boundJson.boundType
        bound.flights         = boundJson.flights.map(&:number)
        bound.departure_code  = boundJson.departureAirport.code
        bound.departure_city  = boundJson.departureAirport.name
        bound.departure_state = boundJson.departureAirport.state
        bound.arrival_code    = boundJson.arrivalAirport.code
        bound.arrival_city    = boundJson.arrivalAirport.name
        bound.arrival_state   = boundJson.arrivalAirport.state
        bound.departure_time  = bound.departure_airport.local_time "#{boundJson.departureDate} #{boundJson.departureTime}"
        bound.arrival_time    = bound.arrival_airport.local_time   "#{boundJson.departureDate} #{boundJson.arrivalTime}"
        Airport.validate bound.departure_code
        Airport.validate bound.arrival_code

        bound.stops = boundJson.stops.map do |stopJson|
          stop                = Stop.new
          stop.code           = stopJson.airport.code
          stop.city           = stopJson.airport.name
          stop.state          = stopJson.airport.state
          stop.plane_change   = stopJson.change_planes
          stop.arrival_time   = stop.airport.local_time "#{boundJson.departureDate} #{stopJson.arrivalTime}"
          stop.departure_time = stop.airport.local_time "#{boundJson.departureDate} #{stopJson.departureTime}"
          Airport.validate stop.code
          stop
        end

        bound
      end

      res.passengers = json.passengers.map do |passengerJson|
        passenger      = Passenger.new
        passenger.name = passengerJson.name
        passenger
      end

      res
    end

    def self.list(bounds, options = {})
      return "No available reservations" unless bounds && bounds.length > 0

      max_name   = bounds.map(&:passengers).flatten.map(&:name).map(&:length).max
      max_depart = bounds.map(&:departure_ident).map(&:length).max
      max_arrive = bounds.map(&:arrival_ident).map(&:length).max

      out = ""
      bounds.sort_by(&:departure_time).each do |b|
        b.reservation.passengers.each_with_index do |p, i|
          if options[:short]
            leader = i == 0 ? "#{b.reservation.conf}:" : "       "
            depart = b.departure_airport.code
            arrive = b.arrival_airport.code
          else
            leader = i == 0 ? sprintf("#{b.reservation.conf} - SW%-4s:", b.flights.first) : "                "
            depart = sprintf "%#{max_depart}s", b.departure_ident
            arrive = sprintf "%#{max_arrive}s", b.arrival_ident
          end

          name     = sprintf "%-#{max_name}s", p.name
          time     = b.departure_local_time.strftime "%Y-%m-%d %l:%M%P"
          seats    = p.seats_for(b).length > 0 ? " *** #{p.seats_ident_for(b)}" : ""
          stops    = b.stops.length > 0 ? " (+#{b.stops.length})" : "     "

          out += "#{leader} #{name}  #{time}  #{depart} -> #{arrive}#{stops}#{seats}\n"
        end
      end

      out
    end
  end
end
