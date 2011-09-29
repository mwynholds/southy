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

  def checkin(flight)
    if flight.checkin_available?
      legs = @monkey.checkin(flight)
      raise "Too many legs for flight: #{flight.confirmation_number}" if legs.size > 1
      if legs.size > 0
        @config.checkin(legs[0]) if legs.size > 0
        send_email(legs[0])
      end
      legs
    else
      nil
    end
  end

  private

  def send_email(flight)
    return unless flight.email

    message = <<EOM
From: Southy <do-not-reply@internet.com>
To: #{flight.full_name}<#{flight.email}>
Subject: Check-in for Southwest SW#{flight.number} - #{flight.confirmation_number}

You have been successfully checked in to your flight.  Details are as follows:

Boarding position: #{flight.seat}

Confirmation number: #{flight.confirmation_number}
Flight: SW#{flight.number}
Departing: #{flight.depart_date.strftime('%F %l:%M%P')}
Route: #{flight.depart_airport}  -->  #{flight.arrive_airport}

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
