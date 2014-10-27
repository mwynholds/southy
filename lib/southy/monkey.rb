require 'nokogiri'
require 'net/https'
require 'fileutils'

class Southy::Monkey

  def initialize(config = nil)
    @config = config

    @http = Net::HTTP.new 'www.southwest.com'
    @https = Net::HTTP.new 'www.southwest.com', 443
    @https.use_ssl = true

    verify_https = false
    certs = File.join File.dirname(__FILE__), "../../etc/certs"
    if File.exists? '/etc/ssl/certs'  # Ubuntu
      @https.ca_path = '/etc/ssl/certs'
      verify_https = true
    elsif File.directory? certs
      @https.ca_path = certs
      verify_https = true
    else
      @https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    if verify_https
      @https.verify_mode = OpenSSL::SSL::VERIFY_PEER
      @https.verify_depth = 5
    end
  end

  def fetch_confirmation_page(conf, first_name, last_name)
    request = Net::HTTP::Post.new '/flight/view-air-reservation.html'
    request.set_form_data :confirmationNumber => conf,
                          :confirmationNumberFirstName => first_name,
                          :confirmationNumberLastName => last_name
    response = fetch request, true
    @config.save_file conf, "confirm.html", response.body
    Nokogiri::HTML response.body
  end

  def lookup(conf, first_name, last_name)
    doc = fetch_confirmation_page conf, first_name, last_name

    legs = []
    doc.css('.itinerary_container').each do |container_node|
      container_node.css('.passenger_row_name').each do |passenger_node|
        container_node.css('.airProductItineraryTable').each do |journey_node|
          flight = Southy::Flight.new

          names = passenger_node.text.split.map(&:capitalize)
          flight.first_name = names[0]
          flight.last_name = names[1]

          flight.confirmation_number = container_node.css('.confirmation_number').text.strip

          leg_nodes = journey_node.css('.flightRouting .routingDetailsStops')
          leg_depart = leg_nodes.first
          leg_arrive = leg_nodes.last

          flight.number = journey_node.css('.flightNumber strong')[0].text.sub(/^#/, '')

          depart_airport_info = leg_depart.css('strong').text.strip
          flight.depart_code = depart_airport_info.scan(/([A-Z]{3})/)[0][0]
          flight.depart_airport = depart_airport_info.sub("(#{flight.depart_code})", '').strip

          arrive_airport_info = leg_arrive.css('strong').text.strip
          flight.arrive_code = arrive_airport_info.scan(/([A-Z]{3})/)[0][0]
          flight.arrive_airport = arrive_airport_info.sub("(#{flight.arrive_code})", '').strip

          depart_airport = Southy::Airport.lookup flight.depart_code
          if depart_airport
            date = journey_node.css('.departureDate .travelDateTime').text.strip
            time = journey_node.css('.routingDetailsTimes.departure')[0].text.strip
            local = DateTime.parse("#{date} #{time}")
            flight.depart_date = Southy::Flight.utc_date_time(local, flight.depart_code)

            legs << flight
          else
            @config.log "Unknown airport code: #{flight.depart_code}"
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
    checkin_options.css('input').each_with_index do |input_node, i|
      input_id = input_node['id']
      if input_id =~ /^checkinPassengers/
        data[input_id] = 'true'
      end
    end
    request.set_form_data data
    set_cookies response, request
    response = fetch request

    request = Net::HTTP::Post.new '/flight/selectCheckinDocDelivery.html'
    data = { :optionPrint => 'true' }
    request.set_form_data data
    set_cookies response, request
    response = fetch request

    body = response.body
    body.gsub!( /href="\//, 'href="http://www.southwest.com/' )
    body.gsub!( /src="\//,  'src="http://www.southwest.com/'  )
    @config.save_file flight.conf, "#{flight.number}-checkin.html", body
    Nokogiri::HTML body
  end

  def checkin(flights)
    doc = fetch_flight_documents_page flights

    checkin_docs = doc.css '.checkinDocument'

    boarding_passes = []
    checked_in_flights = []
    checkin_docs.each do |node|
      number = node.css('.flight_number')[0].text.strip
      first_name = node.css('.passengerFirstName')[0].text.strip.capitalize
      last_name = node.css('.passengerLastName')[0].text.strip.capitalize
      checked_in_flight = flights.find { |f| f.number == number &&
                                             f.first_name == first_name &&
                                             ( f.last_name == last_name || f.last_name == last_name.split[0] ) }

      boarding_passes << "#{number} - #{first_name} #{last_name}"
      if checked_in_flight
        checked_in_flight.group = node.css('.group > *')[0][:alt]
        digits = node.css('.position > *').map { |p| p[:alt].to_i }
        checked_in_flight.position = digits[0] * 10 + digits[1]
        checked_in_flights << checked_in_flight
      end
    end

    if checked_in_flights.empty?
      puts "Cannot find flights for any boarding passes:"
      boarding_passes.each { |bp| puts "  #{bp}" }
    end

    { :flights => checked_in_flights, :doc => doc.to_s }
  end

  private

  def fetch(request, https = false)
    response = https ? @https.request(request) : @http.request(request)

    while response.is_a? Net::HTTPRedirection
      location = response['Location']
      path = location.sub(/^https?:\/\/[^\/]+/, '')
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
  attr_writer :itinerary

  def initialize(itinerary = nil)
    @itinerary = itinerary
  end

  def fetch_confirmation_page(conf, first_name, last_name)
    lookup_file = File.dirname(__FILE__) + "/../../test/fixtures/#{@itinerary}/confirm.html"
    Nokogiri::HTML IO.read(lookup_file)
  end

  def fetch_flight_documents_page(flights)
    flight = flights[0]
    checkin_file = File.dirname(__FILE__) + "/../../test/fixtures/#{@itinerary}/#{flight.number}-checkin.html"
    Nokogiri::HTML IO.read(checkin_file)
  end
end
