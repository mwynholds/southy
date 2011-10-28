require 'net/smtp'

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

  def checkin(flights)
    if flights[0].checkin_available?
      checked_in_flights = @monkey.checkin(flights)
      if checked_in_flights.size > 0
        checked_in_flights.each do |checked_in_flight|
          @config.checkin(checked_in_flight)
        end
        send_email(checked_in_flights)
      end
      checked_in_flights
    else
      nil
    end
  end

  private

  def send_email(flights)
    flight = flights[0]
    return unless flight.email

    seats = ""
    flights.each do |f|
      seats += "#{f.full_name} : #{f.seat}\n"
    end

    local = Southy::Flight.local_date_time(flight.depart_date, flight.depart_code)

    message = <<EOM
From: Southy <southy@carbonfive.com>
To: #{flight.full_name} <#{flight.email}>
Subject: You are checked in for Southwest flight #{flight.number} to #{flight.arrive_airport} (#{flight.arrive_code})

You have been successfully checked in to your flight(s).  Details are as follows:

Confirmation number : #{flight.confirmation_number}
Flight : SW#{flight.number}
Departing : #{local.strftime('%F %l:%M%P')}
Route : #{flight.depart_airport} (#{flight.depart_code}) --> #{flight.arrive_airport} (#{flight.arrive_code})

#{seats}

Please note that you must print your boarding pass online or at the airport:
http://www.southwest.com/flight/retrieveCheckinDoc.html?forceNewSession=yes

Love, southy
EOM

    sent = false
    %w(localhost mail smtp).each do |host|
      begin
        Net::SMTP.start(host) do |smtp|
          smtp.send_message message, 'do-not-reply@internet.com', flight.email
        end
        sent = true
      rescue
      end
    end

    puts "Unable to send check-in email" unless sent
  end

end
