require 'net/smtp'
require 'pdfkit'

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

  def checkin(flights, opts = {})
    opts = { :pdf => true }.merge(opts)

    if flights[0].checkin_available?
      info = @monkey.checkin(flights)
      checked_in_flights = info[:flights]
      doc = info[:doc]
      if checked_in_flights.size > 0
        checked_in_flights.each do |checked_in_flight|
          @config.checkin(checked_in_flight)
        end
        pdf = (opts[:pdf] && doc ? generate_pdf(doc) : nil)
        send_email(checked_in_flights, pdf)
      end
      @config.log "Checked in #{flights[0].conf} - #{checked_in_flights.length} boarding passes"
      checked_in_flights
    else
      nil
    end
  end

  private

  def generate_pdf(doc)
    PDFKit.new(doc).to_pdf
  rescue => e
    @config.log "Error generating PDF", e
    nil
  end

  def generate_email(flights, pdf)
    flight = flights[0]
    return nil unless flight.email

    seats = ""
    flights.each do |f|
      seats += "#{f.full_name} : #{f.seat}\n"
    end

    local = Southy::Flight.local_date_time(flight.depart_date, flight.depart_code)
    filename = "SW#{flight.number}-boarding-passes.pdf"
    marker = 'MIMECONTENTMARKER'

    if pdf
      footer = <<EOM
Your boarding passes are attached as a PDF.  You can print them and bring them to the airport.
EOM
    else
      footer = <<EOM
Please note that you must print your boarding pass online or at the airport:
http://www.southwest.com/flight/retrieveCheckinDoc.html?forceNewSession=yes
EOM
    end

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
    #{footer}
Love, southy
EOM

    if pdf
      encoded_pdf = [pdf].pack('m')
      message += <<EOM
--#{marker}
Content-Type: multipart/mixed; name=\"#{filename}\"
Content-Transfer-Encoding:base64
Content-Disposition: attachment; filename="#{filename}"

#{encoded_pdf}
--#{marker}--
EOM
    end

    message
  end

  def send_email(flights, pdf)
    message = generate_email(flights, pdf)
    return if message.nil?

    flight = flights[0]
    return if flight.nil? || flight.email.nil?

    sent = false
    errors = {}
    hosts = @config.smtp_host ? [ @config.smtp_host ] : %w(localhost mail smtp)
    port = @config.smtp_port
    hosts.each do |host|
      begin
        unless sent
          Net::SMTP.start(host, port) do |smtp|
            smtp.send_message message, 'do-not-reply@internet.com', flight.email
          end
          sent = true
        end
      rescue => e
        errors[host] = e
      end
    end

    unless sent
      puts "Unable to send check-in email"
      errors.each do |host, e|
        @config.log "Unable to send email with host: #{host}", e
      end
    end
  end

end
