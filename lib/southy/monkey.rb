require 'json'
require 'net/https'
require 'fileutils'
require 'pp'
require 'tzinfo'

class Southy::Monkey

  DEBUG = false

  def initialize(config = nil)
    @config = config

    @hostname = 'mobile.southwest.com'
    @api_key = 'l7xx0a43088fe6254712b10787646d1b298e'

    @https = Net::HTTP.new @hostname, 443
    @https.use_ssl = true
    @https.verify_mode = OpenSSL::SSL::VERIFY_PEER
    @https.verify_depth = 5
    #@https.ca_path = '/etc/ssl/certs' if File.exists? '/etc/ssl/certs'  # Ubuntu
  end

  def core_form_data
    { :appID => 'swa', :appver => '2.17.0', :channel => 'wap', :platform => 'thinclient', :cacheid => '', :rcid => 'spaiphone' }
  end

  def parse_json(response)
    if response.body == nil || response.body == ''
      @config.log "Empty response body returned"
      return { 'errmsg' => "empty response body - #{response.code} (#{response.msg})"}
    end
    JSON.parse response.body
  end

  def validate_airport_code(code)
    if Southy::Airport.lookup code
      true
    else
      @config.log "Unknown airport code: #{code}"
      false
    end
  end

  def alternate_names(first, last)
    f, l = first.split(' '), last.split(' ')
    if f.length == 1 && l.length == 2
      return [ "#{f[0]} #{l[0]}", l[1] ]
    elsif f.length == 2 && l.length == 1
      return [ f[0], "#{f[1]} #{l[0]}" ]
    end
    [ first, last ]
  end

  def fetch_trip_info(conf, first_name, last_name)
    uri = URI("https://#{@hostname}/api/mobile-air-operations/v1/mobile-air-operations/page/check-in/#{conf}")
    uri.query = URI.encode_www_form(
      'first-name' => first_name,
      'last-name'  => last_name
    )
    request = Net::HTTP::Get.new uri
    json = fetch_json request
    @config.save_file conf, 'record-locator.json', json
    json
  end

  def lookup(conf, first_name, last_name)
    json = fetch_trip_info conf, first_name, last_name

    statusCode = json['httpStatusCode']

    if statusCode == 'NOT_FOUND'
      alternate_names(first_name, last_name).tap do |alt_first, alt_last|
        if alt_first != first_name || alt_last != last_name
          json = fetch_trip_info conf, alt_first, alt_last
        end
      end
    end

    statusCode = json['httpStatusCode']
    code = json['code']
    message = json['message']

    if statusCode
      puts json
      ident = "#{conf} #{first_name} #{last_name}"
      @config.log "Error looking up flights for #{ident} - #{statusCode} / #{code} - #{message}"
    end

    if statusCode == 'BAD_REQUEST'
      return { error: 'unknown', reason: statusCode, flights: [] }
    end

    if statusCode == 'NOT_FOUND'
      return { error: 'invalid', reason: message, flights: [] } if code == 404511166
      return { error: 'unknown', reason: message, flights: [] }
    end

    page = json['checkInViewReservationPage']
    return { error: 'failure', reason: 'no reservation', flights: [] } unless page

    cards = page['cards']
    return { error: 'failure', reason: 'no segments', flights: [] } unless cards

    checkinInfo = page['_v1_infoNeededToCheckin'] && page['_v1_infoNeededToCheckin']['body']
    return { error: 'failure', reason: 'no checkin info', flights: [] } unless checkinInfo

    response = { error: nil, flights: {} }
    cards.each do |card|
      flights = card['flights']
      flights.each do |flight|

        depart_code = flight['originAirportCode']
        arrive_code = flight['destinationAirportCode']
        next unless validate_airport_code(depart_code) && validate_airport_code(arrive_code)

        depart_airport = Southy::Airport.lookup depart_code
        arrive_airport = Southy::Airport.lookup arrive_code

        tz          = TZInfo::Timezone.get depart_airport.timezone
        utc         = tz.local_to_utc DateTime.parse("#{flight['departureDate']} #{flight['departureTime']}")
        depart_date = Southy::Flight.local_date_time utc, depart_code

        names = checkinInfo['names']
        names.each do |name|
          f = Southy::Flight.new
          f.confirmation_number = conf
          f.first_name          = name['firstName'].capitalize
          f.last_name           = name['lastName'].capitalize
          f.number              = flight['flightNumber']
          f.depart_date         = depart_date
          f.depart_code         = depart_code
          f.depart_airport      = depart_airport.name
          f.arrive_code         = arrive_code
          f.arrive_airport      = arrive_airport.name

          response[:flights][conf] ||= []
          response[:flights][conf] << f
        end
      end
    end

    response
  end

  def fetch_checkin_info(conf, first_name, last_name, sessionToken)
    uri = URI("https://#{@hostname}/api/mobile-air-operations/v1/mobile-air-operations/page/check-in")
    request = Net::HTTP::Post.new uri
    request.body = {
      recordLocator: conf,
      firstName: first_name,
      lastName: last_name,
      checkInSessionToken: sessionToken
    }.to_json
    request.content_type = 'application/json'
    json = fetch_json request
    @config.save_file conf, "boarding-passes-#{first_name.downcase}-#{last_name.downcase}.json", json
    json
  end

  def checkin(flights)
    checked_in_flights = []
    flight = flights[0]
    json = fetch_trip_info flight.confirmation_number, flight.first_name, flight.last_name
    sessionToken = json['checkInSessionToken']

    json = fetch_checkin_info flight.confirmation_number, flight.first_name, flight.last_name, sessionToken

    errmsg = json['errmsg']
    if errmsg
      puts errmsg
      return { :flights => [] }
    end

    page = json['checkInConfirmationPage']
    flightNodes = page['flights']

    flightNodes.each do |flightNode|
      num = flightNode['flightNumber']

      passengers = flightNode['passengers']
      passengers.each do |passenger|
        name = passenger['name']

        existing = flights.find { |f| f.number == num && f.full_name == name }
        if existing
          existing.group = passenger['boardingGroup']
          existing.position = passenger['boardingPosition']
          checked_in_flights << existing
        end
      end
    end

    { :flights => checked_in_flights.compact }
  end

  private

  def fetch_json(request, n = 0)
    puts "Fetch #{request.path}" if DEBUG
    request['User-Agent'] = 'Mozilla/5.0 (iPhone; CPU iPhone OS 8_0 like Mac OS X) AppleWebKit/600.1.3 (KHTML, like Gecko) Version/8.0 Mobile/12A4345d Safari/600.1.4'
    request['X-API-Key'] = @api_key

    response = @https.request(request)

    json = parse_json response

    if json['errmsg'] && json['opstatus'] && json['opstatus'] != 0 && n <= 10  # technical error, try again (for a while)
      fetch_json request, n + 1
    else
      json
    end
  end
end

class Southy::TestMonkey < Southy::Monkey
  def get_json(conf, name)
    base = File.dirname(__FILE__) + "/../../test/fixtures/#{conf}/#{name}"
    last = "#{base}.json"
    n = 1
    while File.exist? "#{base}_#{n}.json"
      last = "#{base}_#{n}.json"
      n += 1
    end
    JSON.parse IO.read(last).strip
  end

  def fetch_trip_info(conf, first_name, last_name)
    get_json conf, "record-locator"
  end
end
