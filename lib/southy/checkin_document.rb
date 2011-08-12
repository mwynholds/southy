class Southy::CheckinDocument
  attr_accessor :first_name, :last_name, :flight, :depart_date, :confirmation_number,
                :depart_airport, :arrive_airport, :depart_time, :group, :position

  def self.parse(node)
    doc = Southy::CheckinDocument.new
    doc.first_name = node.find('.passengerFirstName').text.capitalize
    doc.last_name = node.find('.passengerLastName').text.capitalize
    doc.flight = node.find('.flight_number').text
    doc.depart_date = node.find('.depart_date').text
    doc.confirmation_number = node.find('.pnr_value').text
    doc.depart_airport = node.find('.depart_station').text.capitalize
    doc.arrive_airport = node.find('.arrive_station').text.capitalize
    doc.depart_time = node.find(:xpath, '//span[@class="airport"]').text.gsub(/(#{doc.depart_airport}|#{doc.arrive_airport})/i, '').strip
    doc.group = node.find('.group')[:alt]
    digits = node.all('.position').map { |p| p[:alt].to_i }
    doc.position = digits[0] * 10 + digits[1]
    doc
  end
end