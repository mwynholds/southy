require 'date'
require 'csv'
require 'tzinfo'

class Southy::Flight
  attr_accessor :first_name, :last_name, :email, :number, :depart_date, :confirmation_number,
                :depart_airport, :depart_code, :arrive_airport, :arrive_code,
                :group, :position

  def self.from_csv(line)
    pieces = line.parse_csv
    flight = Southy::Flight.new
    flight.confirmation_number = pieces[0]
    flight.first_name = pieces[1]
    flight.last_name = pieces[2]
    flight.email = pieces[3]
    flight.number = pieces[4]
    flight.depart_airport = pieces[6]
    flight.depart_code = pieces[7]
    flight.arrive_airport = pieces[8]
    flight.arrive_code = pieces[9]
    flight.depart_date = pieces[5] ? DateTime.parse(pieces[5]) : nil

    if flight.depart_code && flight.depart_date
      tz = TZInfo::Timezone.get(Southy::Timezones.lookup(flight.depart_code))
      flight.depart_date = flight.depart_date.new_offset(tz.strftime("%Z"))
    end

    flight.group = pieces[10]
    flight.position = pieces[11] ? pieces[11].to_i : nil
    flight
  end

  def self.list(flights, options = {})
    max_name = flights.map { |f| f.full_name.length }.max
    max_email = flights.map { |f| f.email ? f.email.length : 0 }.max
    flights.each do |f|
      puts f.to_s(max_name, max_email, options[:verbose])
    end
  end

  def initialize(attrs = {})
    attrs.each do |n,v|
      self.send "#{n}=".to_sym, v
    end
  end

  def apply_confirmation(container, first_leg, leg)
    names = container.css('.passenger_row_name').text.split.map &:capitalize
    self.first_name = names[0]
    self.last_name = names[1]

    self.confirmation_number = container.css('.confirmation_number').text.strip

    leg_pieces = leg.css('.segmentsCell .segmentLegDetails')
    leg_depart = leg_pieces[0]
    leg_arrive = leg_pieces[1]

    self.number = leg.css('.flightNumberCell div')[1].text.sub(/^#/, '')
    self.depart_airport = leg_depart.css('.segmentCityName').text.strip
    self.depart_code = leg_depart.css('.segmentStation').text.strip.scan(/([A-Z]{3})/)[0][0]
    self.arrive_airport = leg_arrive.css('.segmentCityName').text.strip
    self.arrive_code = leg_arrive.css('.segmentStation').text.strip.scan(/([A-Z]{3})/)[0][0]

    date = leg.css('.travelTimeCell .departureLongDate').text.strip
    date = first_leg.css('.travelTimeCell .departureLongDate').text.strip if date.empty?
    time = leg_depart.css('.segmentTime').text + leg_depart.css('.segmentTimeAMPM').text.strip
    tz = TZInfo::Timezone.get(Southy::Timezones.lookup(self.depart_code))
    self.depart_date = tz.local_to_utc DateTime.parse("#{date} #{time}")

    self
  end

  def apply_checkin(node)
    self.group = node.css('.group')[0][:alt]
    digits = node.css('.position').map { |p| p[:alt].to_i }
    self.position = digits[0] * 10 + digits[1]

    self
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def full_name_with_email
    "#{full_name} (#{email})"
  end

  def seat
    "#{group}#{position}"
  end

  def confirmed?
    ! depart_date.nil?
  end

  def checkin_available?
    return false unless confirmed?
    return false if checked_in?
    return false if depart_date < DateTime.now  #oops, missed this flight :-)
    depart_date <= DateTime.now + 1
  end

  def checked_in?
    group && position
  end

  def to_csv
    [ confirmation_number, first_name, last_name, email, number, depart_date,
      depart_airport, depart_code, arrive_airport, arrive_code, group, position ].to_csv
  end

  def to_s(max_name = 0, max_email = 0, verbose = false)
    f = self
    num = lj "SW#{f.number}", 6
    fn = lj f.full_name, max_name
    seat = f.checked_in? ? " *** #{f.seat}" : ''
    if verbose
      em = '  ' + lj(f.email || "--", max_email)
      date = f.depart_date.strftime('%F %l:%M%P %Z')
      route = "#{f.depart_airport} (#{f.depart_code}) -> #{f.arrive_airport} (#{f.arrive_code})"
    else
      em = ''
      date = f.depart_date.strftime('%F %l:%M%P')
      route = "#{f.depart_airport} (#{f.depart_code}) -> #{f.arrive_airport} (#{f.arrive_code})"
# route = "#{f.depart_code} -> #{f.arrive_code}"
    end
    if f.confirmed?
      "#{f.confirmation_number} - #{num}: #{fn}#{em}  #{date}  #{route}#{seat}"
    else
      "#{f.confirmation_number} - SW????: #{fn}#{em}"
    end
  end

  def <=>(fles)
    return -1 if self.confirmed? && ! fles.confirmed?
    return 1  if fles.confirmed? && ! self.confirmed?
    return self.confirmation_number <=> fles.confirmation_number if ! self.confirmed?
    self.depart_date <=> fles.depart_date
  end

  private

  def lj(str, max)
    str and max > 0 ? str.ljust(max, ' ') : str
  end
end
