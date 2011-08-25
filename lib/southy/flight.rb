require 'date'
require 'csv'

class Southy::Flight
  attr_accessor :first_name, :last_name, :number, :depart_date, :confirmation_number, :depart_airport, :arrive_airport

  def self.parse(node)
    flight = Southy::Flight.new
    names = node.find('.passenger_row_name').text.split.map &:capitalize
    flight.first_name = names[0]
    flight.last_name = names[1]

    flight.confirmation_number = node.find('.confirmation_number').text

    leg = node.all('tr.whiteRow')[0]
    leg_pieces = leg.all('.segmentsCell.firstSegmentCell .segmentLegDetails')
    leg_depart = leg_pieces[0]
    leg_arrive = leg_pieces[1]
    
    date = leg.find('.travelTimeCell .departureLongDate').text
    time = leg_depart.find('.segmentTime').text + leg_depart.find('.segmentTimeAMPM').text
    flight.number = leg.all('.flightNumberCell.firstSegmentCell div')[1].text.sub(/^#/, '')
    flight.depart_date = DateTime.parse("#{date} #{time}")
    flight.depart_airport = leg_depart.find('.segmentCityName').text
    flight.arrive_airport = leg_arrive.find('.segmentCityName').text

    flight
  end

  def self.from_csv(line)
    pieces = line.parse_csv
    flight = Southy::Flight.new
    flight.confirmation_number = pieces[0]
    flight.first_name = pieces[1]
    flight.last_name = pieces[2]
    flight.number = pieces[3]
    flight.depart_date = pieces[4] ? DateTime.parse(pieces[4]) : nil
    flight.depart_airport = pieces[5]
    flight.arrive_airport = pieces[6]
    flight
  end

  def initialize(attrs = {})
    attrs.each do |n,v|
      self.send "#{n}=".to_sym, v
    end
  end

  def confirmed?
    ! depart_date.nil?
  end

  def checkinable?
    false
  end

  def to_csv
    [confirmation_number, first_name, last_name, number, depart_date, depart_airport, arrive_airport].to_csv
  end

  def to_s
    if confirmed?
      "SW#{number}: #{first_name} #{last_name}, #{depart_date.strftime('%F %l:%M%P')} #{depart_airport} -> #{arrive_airport} (#{confirmation_number})"
    else
      "Unconfirmed: #{first_name} #{last_name} (#{confirmation_number})"
    end
  end

  def <=>(fles)
    return -1 if self.confirmed? && ! fles.confirmed?
    return 1  if fles.confirmed? && ! self.confirmed?
    return self.to_s <=> fles.to_s if ! self.confirmed?
    self.depart_date <=> fles.depart_date
  end
end