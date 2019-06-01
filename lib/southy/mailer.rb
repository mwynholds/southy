require 'net/smtp'

class Southy::Mailer
  def initialize(config)
    @config = config
  end

  def send_email(bound)
    message = generate_email bound
    return false unless message
    return false unless bound.reservation.email

    Net::SMTP.start(@config.smtp_host, @config.smtp_port, @config.smtp_domain, @config.smtp_account, @config.smtp_password, :plain) do |smtp|
      smtp.send_message message, 'southy@carbonfive.com', flight.email
    end
  end

  def generate_email(bound)
    return nil unless bound.reservation.email

    seats = reservation.passengers.map { |p| "#{p.name} : #{p.seats_for(bound).map(&:ident)}" }.join("\n")
    marker = 'MIMECONTENTMARKER'

    message = <<EOM
From: Southy <southy@carbonfive.com>
To: #{passenger.first.name} <#{reservation.email}>
Subject: You are checked in for Southwest conf #{reservation.conf} to #{reservation.destination_ident})
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary=#{marker}
--#{marker}
Content-Type: text/plain
Content-Transfer-Encoding:8bit

You have been successfully checked in to your flight(s).  Details are as follows:

Confirmation number : #{bound.reservation.conf}
Flight : SW#{bound.flights.first}
Departing : #{bound.local_departure_time.strftime('%F %l:%M%P')}
Route : #{bound.departure_airport.ident} --> #{bound.arrival_airport.ident}

#{seats}
Love, southy
EOM
    message
  end
end
