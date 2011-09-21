require 'date'
require 'csv'

class Southy::Flight
  attr_accessor :first_name, :last_name, :email, :number, :depart_date, :confirmation_number,
                :depart_airport, :arrive_airport, :group, :position

  def self.from_dom(container, leg)
    flight = Southy::Flight.new
    names = container.css('.passenger_row_name').text.split.map &:capitalize
    flight.first_name = names[0]
    flight.last_name = names[1]

    flight.confirmation_number = container.css('.confirmation_number').text

    leg_pieces = leg.css('.segmentsCell.firstSegmentCell .segmentLegDetails')
    leg_depart = leg_pieces[0]
    leg_arrive = leg_pieces[1]
    
    date = leg.css('.travelTimeCell .departureLongDate').text
    time = leg_depart.css('.segmentTime').text + leg_depart.css('.segmentTimeAMPM').text
    flight.number = leg.css('.flightNumberCell.firstSegmentCell div')[1].text.sub(/^#/, '')
    flight.depart_date = DateTime.parse("#{date} #{time}")
    flight.depart_airport = leg_depart.css('.segmentCityName').text
    flight.arrive_airport = leg_arrive.css('.segmentCityName').text

    flight
  end

  def self.from_csv(line)
    pieces = line.parse_csv
    flight = Southy::Flight.new
    flight.confirmation_number = pieces[0]
    flight.first_name = pieces[1]
    flight.last_name = pieces[2]
    flight.email = pieces[3]
    flight.number = pieces[4]
    flight.depart_date = pieces[5] ? DateTime.parse(pieces[5]) : nil
    flight.depart_airport = pieces[6]
    flight.arrive_airport = pieces[7]
    flight.group = pieces[8]
    flight.position = pieces[9] ? pieces[9].to_i : nil
    flight
  end

  def self.list(flights)
    max_name = flights.map { |f| f.full_name.length }.max
    max_email = flights.map { |f| f.email ? f.email.length : 0 }.max
    flights.each do |f|
      num = lj "SW#{f.number}", 6
      fn = lj f.full_name, max_name
      em = lj(f.email || "--", max_email)
      if f.confirmed?
        puts "#{f.confirmation_number} - #{num}: #{fn}  #{em}  #{f.depart_date.strftime('%F %l:%M%P')} #{f.depart_airport} -> #{f.arrive_airport}"
      else
        puts "#{f.confirmation_number} - SW????: #{fn}  #{em}"
      end
    end
  end

  def initialize(attrs = {})
    attrs.each do |n,v|
      self.send "#{n}=".to_sym, v
    end
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
    return false if depart_date < DateTime.now  #oops, missed this flight :-)
    depart_date <= DateTime.now + 1
  end
  
  def checked_in?
    group && position
  end

  def to_csv
    [confirmation_number, first_name, last_name, email, number, depart_date, depart_airport, arrive_airport, group, position].to_csv
  end

  def to_s
    Southy::Flight.list [self]
  end

  def <=>(fles)
    return -1 if self.confirmed? && ! fles.confirmed?
    return 1  if fles.confirmed? && ! self.confirmed?
    return self.confirmation_number <=> fles.confirmation_number if ! self.confirmed?
    self.depart_date <=> fles.depart_date
  end

  private

  def self.lj(str, max)
    str and max > 0 ? str.ljust(max, ' ') : str
  end
end