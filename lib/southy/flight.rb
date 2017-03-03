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

  def self.sprint(flights, options = {})
    max_name = flights.map { |f| f.full_name.length }.max
    max_email = flights.map { |f| f.email ? f.email.length : 0 }.max
    max_depart = flights.map { |f| f.depart_airport.length }.max
    max_arrive = flights.map { |f| f.arrive_airport.length }.max

    out = ""
    last = nil
    flights.each do |f|
      subordinate = last && last.conf == f.conf && last.number == f.number
      out +=  f.to_s(:max_name => max_name, :max_email => max_email, :max_depart => max_depart, :max_arrive => max_arrive,
                     :subordinate => subordinate, :verbose => options[:verbose], :short => options[:short])
      out += "\n"
      last = f
    end
    out
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
    self.first_name = names[0...-1].map {|n| n.capitalize}.join(' ')
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
    return false if depart_date < DateTime.now     # oops, missed this flight :-)
    DateTime.now >= depart_date - 1 - _seconds(3)  # start trying 3 seconds early!
  end

  def checkin_time?
    return false unless checkin_available?
    now = DateTime.now
    checkin_time = depart_date - 1
    # try hard for one minute
    now >= checkin_time - _seconds(3) && now <= checkin_time + _seconds(60)
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
    opts = { :max_name => 0, :max_email => 0, :max_depart => 0, :max_arrive => 0,
             :subordinate => false, :verbose => false, :short => false }.merge opts

    out = ''
    if opts[:subordinate]
      out += (' ' * ( opts[:short] ? 8 : 17 ))
    else
      out += conf
      out += ' - ' + ( confirmed? ? ( 'SW' + lj(number, 4) ) : '------' ) unless opts[:short]
      out += ': '
    end

    out += lj(full_name, opts[:max_name])
    out += ( '  ' + lj(email || "--", opts[:max_email]) ) if opts[:verbose]

    if confirmed?
      local = Southy::Flight.local_date_time(depart_date, depart_code)

      out += '  '
      out += local.strftime( opts[:verbose] ? '%F %l:%M%P %Z' : '%F %l:%M%P' )
      out += '  '
      if opts[:short]
        out += "#{depart_code} -> #{arrive_code}"
      else
        depart = lj("#{depart_airport} (#{depart_code})", opts[:max_depart] + 6)
        arrive = lj("#{arrive_airport} (#{arrive_code})", opts[:max_arrive] + 6)
        out += "#{depart} -> #{arrive}"
      end
      out += " *** #{seat}" if checked_in?
    end

    out
  end

  def to_slack_s()
    local = Southy::Flight::local_date_time depart_date, depart_code
    time = local.strftime '%D %R'
    "[ #{conf} ] - #{full_name} - #{time} #{depart_code} -> #{arrive_code}"
  end

  def <=>(fles)
    return -1 if self.confirmed? && ! fles.confirmed?
    return 1  if fles.confirmed? && ! self.confirmed?
    return self.conf <=> fles.conf if ! self.confirmed?
    Southy::Flight.compare(self, fles, :depart_date, :conf, :number, :full_name)
  end

  def matches_completely?(other)
    self.conf == other.conf &&
      self.full_name == other.full_name &&
      self.number == other.number &&
      self.depart_code == other.depart_code &&
      self.depart_date == other.depart_date
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
