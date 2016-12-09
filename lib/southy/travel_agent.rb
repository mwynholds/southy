class Southy::TravelAgent

  attr_reader :config, :monkey

  def initialize(config, opts = {})
    @is_test = opts[:test] == true
    @config = config
    @mailer = Southy::Mailer.new config
  end

  def monkey
    @is_test ? Southy::TestMonkey.new : Southy::Monkey.new(config)
  end

  def confirm(flight_info)
    response = monkey.lookup(flight_info.conf, flight_info.first_name, flight_info.last_name)
    if response[:error]
      if response[:error] == 'unknown'
        @config.log "Flight not removed due to '#{response[:error]}' : #{flight_info.conf} (#{flight_info.full_name})"
      else
        @config.remove flight_info.conf
        @config.log "Flight removed due to '#{response[:error]}' : #{flight_info.conf} (#{flight_info.full_name})"
      end
      return response
    end

    flights = response[:flights]
    flights.each do |conf, legs|
      unless conf
        @config.log "No confirmation number in response for: #{flight_info.conf} (#{flight_info.full_name})"
        next
      end

      ident = "#{conf} (#{legs[0].first_name} #{legs[0].last_name}) - #{legs.length} legs"
      ident += " -- NEW!" unless flight_info.conf == conf
      if @config.matches legs
        @config.log "No changes to #{ident}"
      else
        @config.remove conf
        legs.each do |leg|
          leg.email ||= flight_info.email
          @config.confirm leg
        end
        @config.log "Confirmed #{ident}"
      end
    end

    response
  end

  def checkin(flights)
    flight = flights[0]
    return nil unless flight.checkin_available?

    name = flight.full_name
    len = flights.length
    name += " (and #{len - 1} other passenger#{len > 2 ? 's' : ''})" if len > 1

    info = monkey.checkin(flights)
    checked_in_flights = info[:flights]
    if checked_in_flights.size > 0
      checked_in_flights.each do |checked_in_flight|
        @config.checkin checked_in_flight
      end
      @mailer.send_email checked_in_flights
      seats = checked_in_flights.map(&:seat).join(', ')
      @config.log "Checked in #{flight.conf} for #{name} - #{seats}"
    else
      @config.log "Unable to check in #{flight.conf} for #{name}"
    end
    checked_in_flights
  end

  def resend(flights)
    return false unless flights[0].checked_in?

    @mailer.send_email flights
  end
end
