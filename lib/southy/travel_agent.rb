require 'net/smtp'

class Southy::TravelAgent

  attr_reader :config, :monkey

  def initialize(config, opts = {})
    is_test = opts[:test] == true

    @config = config
    @monkey = is_test ? Southy::TestMonkey.new : Southy::Monkey.new(config)
  end

  def confirm(flight_info)
    response = @monkey.lookup(flight_info.conf, flight_info.first_name, flight_info.last_name)
    if response[:error]
      @config.remove flight_info.conf
      @config.log "Flight removed due to '#{response[:error]}' : #{flight_info.conf} (#{flight_info.full_name})"
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

    info = @monkey.checkin(flights)
    checked_in_flights = info[:flights]
    if checked_in_flights.size > 0
      checked_in_flights.each do |checked_in_flight|
        @config.checkin checked_in_flight
      end
      send_email checked_in_flights
      seats = checked_in_flights.map(&:seat).join(', ')
      @config.log "Checked in #{flight.conf} for #{name} - #{seats}"
    else
      @config.log "Unable to check in #{flight.conf} for #{name}"
    end
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
