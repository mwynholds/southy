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
    flight.group = pieces[10]
    flight.position = pieces[11] ? pieces[11].to_i : nil
    flight
  end

  def self.list(flights, options = {})
    max_name = flights.map { |f| f.full_name.length }.max
    max_email = flights.map { |f| f.email ? f.email.length : 0 }.max

    last = nil
    flights.each do |f|
      subordinate = last && last.conf == f.conf && last.number == f.number
      puts f.to_s(:max_name => max_name, :max_email => max_email, :subordinate => subordinate, :verbose => options[:verbose])
      last = f
    end
  end

  def initialize(attrs = {})
    attrs.each do |n,v|
      self.send "#{n}=".to_sym, v
    end
  end

  def apply_confirmation(container, passenger, first_leg, leg)
    names = passenger.text.split.map &:capitalize
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
    time = leg_depart.css('.segmentTime').text.strip + leg_depart.css('.segmentTimeAMPM').text.strip
    local = DateTime.parse("#{date} #{time}")
    self.depart_date = Southy::Flight.utc_date_time(local, self.depart_code)

    self
  end

  def apply_checkin(node)
    self.group = node.css('.group')[0][:alt]
    digits = node.css('.position').map { |p| p[:alt].to_i }
    self.position = digits[0] * 10 + digits[1]

    self
  end

  def conf
    confirmation_number
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
      depart_airport, depart_code, arrive_airport, arrive_code, group, position ].to_csv.gsub(/,*$/, '')
  end

  def to_s(opts = {})
    opts = { :max_name => 0, :max_email => 0, :subordinate => false, :verbose => false }.merge opts

    out = ''
    if opts[:subordinate]
      out += (' ' * 17)
    else
      out += conf + " - "
      out += 'SW' + ( confirmed? ? lj(number, 4) : '????' )
      out += ': '
    end

    out += lj(full_name, opts[:max_name])
    out += ( '  ' + lj(email || "--", opts[:max_email]) ) if opts[:verbose]

    if confirmed?
      local = Southy::Flight.local_date_time(depart_date, depart_code)

      out += '  '
      out += local.strftime( opts[:verbose] ? '%F %l:%M%P %Z' : '%F %l:%M%P' )
      out += '  '
      out += "#{depart_airport} (#{depart_code}) -> #{arrive_airport} (#{arrive_code})"
      out += " *** #{seat}" if checked_in?
    end

    out
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

  def self.utc_date_time(local, airport_code)
    tz = TZInfo::Timezone.get(Southy::Airport.lookup(airport_code).timezone)
    tz.local_to_utc(local)
  end

  def self.local_date_time(utc, airport_code)
    tz = TZInfo::Timezone.get(Southy::Airport.lookup(airport_code).timezone)
    local = tz.utc_to_local(utc)
    offset = tz.period_for_local(local).utc_total_offset / (68 * 60)
    DateTime.parse( local.to_s.sub('+00:00', "#{offset}:00") )
  end
end
