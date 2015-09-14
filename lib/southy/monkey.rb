require 'nokogiri'
require 'json'
require 'net/https'
require 'fileutils'

class Southy::Monkey

  DEBUG = false

  def initialize(config = nil)
    @config = config

    @http = Net::HTTP.new 'mobile.southwest.com'
    @https = Net::HTTP.new 'mobile.southwest.com', 443
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

  def fetch_trip_info(conf, first_name, last_name)
    request = Net::HTTP::Post.new '/middleware/MWServlet'
    request.set_form_data :serviceID => 'viewAirReservation',
                          :confirmationNumber => conf,
                          :confirmationNumberFirstName => first_name,
                          :confirmationNumberLastName => last_name,
                          :searchType => 'ConfirmationNumber',
                          :appID => 'swa',
                          :channel => 'wap',
                          :platform => 'thinclient',
                          :cacheid => '',
                          :rcid => 'spaiphone'
    response = fetch request, true
    json = JSON.parse response.body
    @config.save_file conf, 'info.json', json.pretty_inspect
    json
  end

  def extract_code(str)
    str.scan(/([A-Z]{3})/)[0][0]
  end

  def extract_time(str)
    str.scan(/^(.*[AP]M)/)[0][0]
  end

  def extract_airport(str)
    code = extract_code str
    time = extract_time str
    str = str.sub "(#{code})", ''
    str = str.sub time, ''
    str.strip
  end

  def extract_flight(info, leg_name, leg_type)
    leg_info = info[leg_name]
    return nil unless leg_info

    flight = Southy::Flight.new
    flight.first_name = info['ebchkinfirstName'].capitalize
    flight.last_name = info['ebchkinlastName'].capitalize
    flight.confirmation_number = info['ebchkinConfNo']
    flight.number = leg_info["#{leg_type}FlightNo"]
    flight.depart_code = extract_code leg_info["departCity"]
    flight.depart_airport = extract_airport leg_info["departCity"]
    flight.arrive_code = extract_code leg_info["arrivalCity"]
    flight.arrive_airport = extract_airport leg_info["arrivalCity"]

    depart_airport = Southy::Airport.lookup flight.depart_code
    if depart_airport
      date = leg_info["#{leg_type}Date"]
      time = extract_time leg_info["departCity"]
      local = DateTime.parse "#{date} #{time}"
      flight.depart_date = Southy::Flight.utc_date_time(local, flight.depart_code)
    else
      @config.log "Unknown airport code: #{flight.depart_code}"
      return nil
    end

    flight
  end

  def lookup(conf, first_name, last_name)
    json = fetch_trip_info conf, first_name, last_name

    infos = json['upComingInfo']
    puts "WARNING: Expecting one 'upComingInfo' block but found #{infos.length}" if infos.length > 1
    info = infos[0]
    departing_flight = extract_flight info, 'Depart1', 'depart'
    returning_flight = extract_flight info, 'Return1', 'return'

    [ departing_flight, returning_flight ].compact
  end

  def fetch_flight_documents_page(flights)
    flight = flights[0]

    request = Net::HTTP::Post.new '/flight/retrieveCheckinDoc.html'
    request['Referer'] = 'http://www.southwest.com/flight/retrieveCheckinDoc.html?forceNewSession=yes'
    request.set_form_data :confirmationNumber => flight.confirmation_number,
                          :firstName => flight.first_name,
                          :lastName => flight.last_name,
                          :submitButton => 'Check In'
    response = fetch request, true

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
    response = fetch request, true

    request = Net::HTTP::Post.new '/flight/selectCheckinDocDelivery.html'
    data = { :optionPrint => 'true' }
    request.set_form_data data
    set_cookies response, request
    response = fetch request, true

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
        checked_in_flight.group = nodes_or_children(node, '.group')[0][:alt]
        digits = nodes_or_children(node, '.position').map { |p| p[:alt].to_i }
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

  def nodes_or_children(node, selector)
    n1 = node.css selector
    n2 = node.css "#{selector} > *"
    n1.empty? ? n2 : n1
  end

  def fetch(request, https = false)
    puts "Fetch #{request.path}" if DEBUG
    request['User-Agent'] = 'Mozilla/5.0 (iPhone; CPU iPhone OS 8_0 like Mac OS X) AppleWebKit/600.1.3 (KHTML, like Gecko) Version/8.0 Mobile/12A4345d Safari/600.1.4'
    response = https ? @https.request(request) : @http.request(request)

    while response.is_a? Net::HTTPRedirection
      location = response['Location']
      puts "Redirect to #{location}" if DEBUG
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

    if DEBUG
      puts "Cookies:"
      p cookies
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
