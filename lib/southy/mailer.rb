require 'net/smtp'

class Southy::Mailer
  def initialize(config)
    @config = config
  end

  def send_test_email(recipient)
    flight = Southy::Flight.new(
      email:               recipient,
      first_name:          'Joey',
      last_name:           'Shabadoo',
      confirmation_number: 'ABCDEF',
      number:              '1234',
      depart_airport:      'Los Angeles',
      depart_code:         'LAX',
      arrive_airport:      'San Francisco',
      arrive_code:         'SFO',
      depart_date:         DateTime.now,
      group:               'A',
      position:            '15'
    )
    send_email [flight]
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
end
