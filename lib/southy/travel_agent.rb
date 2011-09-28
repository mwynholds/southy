class Southy::TravelAgent

  attr_reader :config, :monkey

  def initialize(config, monkey)
    @config = config
    @monkey = monkey
  end

  def confirm(flight_info)
    legs = @monkey.lookup(flight_info.confirmation_number, flight_info.first_name, flight_info.last_name)
    if legs.length > 0
      @config.remove flight_info.confirmation_number
      legs.each do |leg|
        leg.email = flight_info.email
        @config.confirm leg
      end
    end
    legs
  end

  def checkin(flight)
    if flight.checkin_available?
      legs = @monkey.checkin(flight)
      raise "Too many legs for flight: #{flight.confirmation_number}" if legs.size > 1
      @config.checkin(legs[0]) if legs.size > 0
      legs
    else
      nil
    end
  end

end