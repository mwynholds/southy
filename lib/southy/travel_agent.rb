class Southy::TravelAgent

  attr_reader :config, :monkey

  def initialize(config, monkey)
    @config = config
    @monkey = monkey
  end

  def confirm(flight)
    legs = @monkey.lookup(flight.confirmation_number, flight.first_name, flight.last_name)
    if legs.length > 0
      @config.remove flight.confirmation_number
      legs.each do |leg|
        leg.email = flight.email
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