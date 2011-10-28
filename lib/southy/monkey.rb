require 'nokogiri'
require 'net/https'
require 'fileutils'

class Southy::Monkey

  def initialize
    @http = Net::HTTP.new 'www.southwest.com'
    @https = Net::HTTP.new 'www.southwest.com', 443
    @https.use_ssl = true

    certs = File.join File.dirname(__FILE__), "../../etc/certs"
    if File.exists? '/etc/ssl/certs'  # Ubuntu
      @https.ca_path = '/etc/ssl/certs'
      @https.verify_mode = OpenSSL::SSL::VERIFY_PEER
      @https.verify_depth = 5
    elsif File.directory? certs
      @https.ca_path = certs
      @https.verify_mode = OpenSSL::SSL::VERIFY_PEER
      @https.verify_depth = 5
    else
      @https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
  end

  def fetch_confirmation_page(conf, first_name, last_name)
    request = Net::HTTP::Post.new '/flight/view-air-reservation.html'
    request.set_form_data :confirmationNumber => conf,
                          :confirmationNumberFirstName => first_name,
                          :confirmationNumberLastName => last_name
    response = fetch request, true
    Nokogiri::HTML response.body
  end

  def lookup(conf, first_name, last_name)
    doc = fetch_confirmation_page conf, first_name, last_name

    legs = []
    doc.css('.itinerary_container').each do |container_node|
      container_node.css('.passenger_row_name').each do |passenger_node|
        container_node.css('.airProductItineraryTable').each do |table_node|
          leg_nodes = table_node.css('tr.whiteRow') + table_node.css('tr.grayRow')
          if leg_nodes.length > 0
            first_leg_node = leg_nodes[0]
            leg_nodes.each do |leg_node|
              flight = Southy::Flight.new

              names = passenger_node.text.split.map &:capitalize
              flight.first_name = names[0]
              flight.last_name = names[1]

              flight.confirmation_number = container_node.css('.confirmation_number').text.strip

              leg_pieces = leg_node.css('.segmentsCell .segmentLegDetails')
              leg_depart = leg_pieces[0]
              leg_arrive = leg_pieces[1]

              flight.number = leg_node.css('.flightNumberCell div')[1].text.sub(/^#/, '')
              flight.depart_airport = leg_depart.css('.segmentCityName').text.strip
              flight.depart_code = leg_depart.css('.segmentStation').text.strip.scan(/([A-Z]{3})/)[0][0]
              flight.arrive_airport = leg_arrive.css('.segmentCityName').text.strip
              flight.arrive_code = leg_arrive.css('.segmentStation').text.strip.scan(/([A-Z]{3})/)[0][0]

              date = leg_node.css('.travelTimeCell .departureLongDate').text.strip
              date = first_leg_node.css('.travelTimeCell .departureLongDate').text.strip if date.empty?
              time = leg_depart.css('.segmentTime').text.strip + leg_depart.css('.segmentTimeAMPM').text.strip
              local = DateTime.parse("#{date} #{time}")
              flight.depart_date = Southy::Flight.utc_date_time(local, flight.depart_code)

              legs << flight
            end
          end
        end
      end
    end

    legs
  end

  def fetch_flight_documents_page(flights)
    flight = flights[0]

    request = Net::HTTP::Post.new '/flight/retrieveCheckinDoc.html'
    request['Referer'] = 'http://www.southwest.com/flight/retrieveCheckinDoc.html?forceNewSession=yes'
    request.set_form_data :confirmationNumber => flight.confirmation_number,
                          :firstName => flight.first_name,
                          :lastName => flight.last_name,
                          :submitButton => 'Check In'
    response = fetch request

    doc = Nokogiri::HTML response.body
    checkin_options = doc.css '#checkinOptions'
    return nil unless checkin_options

    request = Net::HTTP::Post.new '/flight/selectPrintDocument.html'
    data = { :printDocuments => 'Check In' }
    checkin_options.css('.passengerRow').each_with_index do |_, i|
      data["_checkinPassengers[#{i}].selected"] = 'on'
      data["checkinPassengers[#{i}].selected"] = 'true'
    end
    request.set_form_data data
    set_cookies response, request
    response = fetch request

    Nokogiri::HTML response.body
  end

  def checkin(flights)
    doc = fetch_flight_documents_page flights

    checkin_docs = doc.css '.checkinDocument'
    return nil unless checkin_docs.length > 0

    checked_in_flights = []
    checkin_docs.each do |node|
      number = node.css('.flight_number').text.strip
      first_name = node.css('.passengerFirstName').text.strip.capitalize
      last_name = node.css('.passengerLastName').text.strip.capitalize
      checked_in_flight = flights.find { |f| f.number == number && f.first_name == first_name && f.last_name == last_name }
      if checked_in_flight
        checked_in_flight.group = node.css('.group')[0][:alt]
        digits = node.css('.position').map { |p| p[:alt].to_i }
        checked_in_flight.position = digits[0] * 10 + digits[1]

        checked_in_flights << checked_in_flight
      end
    end

    checked_in_flights
  end

  private

  def fetch(request, https = false)
    response = https ? @https.request(request) : @http.request(request)

    while response.is_a? Net::HTTPRedirection
      location = response['Location']
      path = location.sub /^https?:\/\/[^\/]+/, ''
      request = Net::HTTP::Get.new path
      set_cookies response, request
      response = (location =~ /^https:/) ? @https.request(request) : @http.request(request)
    end

    response
  end

  def set_cookies(response, request)
    cookie_header = response.get_fields 'Set-Cookie'
    cookies = {}
    if cookie_header
      cookie_header.each do |c|
        name = c.match(/^([^=]+)=/)[1]
        cookies[name] = c.split(';')[0]
      end
    end

    request['Cookie'] = cookies.values.join('; ') if cookies.length > 0
  end
end

class Southy::TestMonkey < Southy::Monkey
  def fetch_confirmation_page(conf, first_name, last_name)
    lookup_file = File.dirname(__FILE__) + "/../../test/fixtures/itinerary-1/confirm.html"
    Nokogiri::HTML IO.read(lookup_file)
  end

  alias_method :lookup_alias, :lookup
  def lookup(conf, first_name, last_name)
    legs = lookup_alias conf, first_name, last_name

    legs.each do |leg|
      leg.confirmation_number = conf
      leg.first_name = first_name
      leg.last_name = last_name
    end

    while legs[0].depart_date < DateTime.now
      legs.each { |leg| leg.depart_date += 1 }
    end

    legs
  end

  def fetch_flight_documents_page(flight)
    checkin_file = File.dirname(__FILE__) + "/../../test/fixtures/itinerary-1/#{flight.number}-checkin.html"
    Nokogiri::HTML IO.read(checkin_file)
  end
end