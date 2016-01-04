require 'net/smtp'

class Southy::TravelAgent

  attr_reader :config, :monkey

  def initialize(config, opts = {})
    is_test = opts[:test] == true

    @config = config
    @monkey = is_test ? Southy::TestMonkey.new : Southy::Monkey.new(config)
  end

  def confirm(flight_info)
    legs = @monkey.lookup(flight_info.confirmation_number, flight_info.first_name, flight_info.last_name)
    @config.remove flight_info.confirmation_number, flight_info.first_name, flight_info.last_name
    if legs.length > 0
      legs.each do |leg|
        leg.email = flight_info.email
        @config.confirm leg
      end
    end
    @config.log "Confirmed #{flight_info.conf} - #{legs.length} legs"
    legs
  end

  def checkin(flights)
    flight = flights[0]
    return nil unless flight.checkin_available?

    info = @monkey.checkin(flights)
    checked_in_flights = info[:flights]
    if checked_in_flights.size > 0
      checked_in_flights.each do |checked_in_flight|
        @config.checkin checked_in_flight
      end
      send_email checked_in_flights
    end
    @config.log "Checked in #{flights[0].conf} - #{checked_in_flights.length} boarding passes"
    checked_in_flights
  end

  def resend(flights)
    return false unless flights[0].checked_in?

    send_email flights
  end

  private

  def generate_email(flights)
    flight = flights[0]
    return nil unless flight.email

    seats = ""
    flights.each do |f|
      seats += "#{f.full_name} : #{f.seat}\n"
    end

    local = Southy::Flight.local_date_time(flight.depart_date, flight.depart_code)
    marker = 'MIMECONTENTMARKER'

    message = <<EOM
From: Southy <southy@carbonfive.com>
To: #{flight.full_name} <#{flight.email}>
Subject: You are checked in for Southwest flight #{flight.number} to #{flight.arrive_airport} (#{flight.arrive_code})
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary=#{marker}
--#{marker}
Content-Type: text/plain
Content-Transfer-Encoding:8bit

You have been successfully checked in to your flight(s).  Details are as follows:

Confirmation number : #{flight.confirmation_number}
Flight : SW#{flight.number}
Departing : #{local.strftime('%F %l:%M%P')}
Route : #{flight.depart_airport} (#{flight.depart_code}) --> #{flight.arrive_airport} (#{flight.arrive_code})

#{seats}
Love, southy
EOM
    message
  end

  def send_email(flights)
    message = generate_email flights
    return false if message.nil?

    flight = flights[0]
    return false if flight.nil? || flight.email.nil?

    Net::SMTP.start(@config.smtp_host, @config.smtp_port, @config.smtp_domain, @config.smtp_account, @config.smtp_password, :plain) do |smtp|
      smtp.send_message message, 'southy@carbonfive.com', flight.email
    end
  end

end
