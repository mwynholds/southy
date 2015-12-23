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

  def conf
    confirmation_number
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def full_name=(name)
    names = name.split ' '
    self.first_name = names[0...-1].join(' ').capitalize
    self.last_name = names.last.capitalize
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

  def _seconds(n)
    (n / 60.0) / (24 * 60)
  end

  def checkin_available?
    return false unless confirmed?
    return false if checked_in?
    return false if depart_date < DateTime.now      # oops, missed this flight :-)
    DateTime.now >= depart_date - 1 - _seconds(10)  # start trying 10 seconds early!
  end

  def checkin_time?
    return false unless checkin_available?
    now = DateTime.now
    checkin_time = depart_date - 1
    # try hard for one minute
    now >= checkin_time - _seconds(10) && now <= checkin_time + _seconds(60)
  end

  def late_checkin_time?
    return false unless checkin_available?
    now = DateTime.now
    # then keep trying every hour for one minute
    now.min == 0
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
      out += confirmed? ? ( 'SW' + lj(number, 4) ) : '------'
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
    return self.conf <=> fles.conf if ! self.confirmed?
    Southy::Flight.compare(self, fles, :depart_date, :conf, :number, :full_name)
  end

  private

  def self.compare(obj1, obj2, *attrs)
    attrs.each do |attr|
      comp = obj1.send(attr) <=> obj2.send(attr)
      return comp unless comp == 0
    end

    0
  end

  def lj(str, max)
    str and max > 0 ? str.ljust(max, ' ') : str
  end

  def self.utc_date_time(local, airport_code)
    airport = Southy::Airport.lookup airport_code
    return nil unless airport

    tz = TZInfo::Timezone.get airport.timezone
    tz.local_to_utc(local)
  end

  def self.local_date_time(utc, airport_code)
    tz = TZInfo::Timezone.get(Southy::Airport.lookup(airport_code).timezone)
    local = tz.utc_to_local(utc)
    offset = tz.period_for_local(local).utc_total_offset / (60 * 60)
    DateTime.parse( local.to_s.sub('+00:00', "#{offset}:00") )
  end
end
