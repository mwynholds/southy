class Southy::CheckinDocument
  attr_accessor :flight, :depart_date, :confirmation_number, :depart_airport, :arrive_airport, :group, :position

  def self.parse(node)
    doc = Southy::CheckinDocument.new
    doc.flight = node.find('.flight_number').text
    doc.depart_date = node.find('.depart_date').text
    doc.confirmation_number = node.find('.pnr_value').text
    doc.depart_airport = node.find('.depart_station').text
    doc.arrive_airport = node.find('.arrive_station').text
    doc.group = node.find('.group')[:alt]
    digits = node.all('.position').map { |p| p[:alt].to_i }
    doc.position = digits[0] * 10 + digits[1]
    doc
  end
end