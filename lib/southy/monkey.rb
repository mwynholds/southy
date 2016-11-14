require 'json'
require 'net/https'
require 'fileutils'
require 'pp'

class Southy::Monkey

  DEBUG = false

  def initialize(config = nil)
    @config = config
    @cookies = []

    @https = Net::HTTP.new 'mobile.southwest.com', 443
    @https.use_ssl = true
    @https.verify_mode = OpenSSL::SSL::VERIFY_PEER
    @https.verify_depth = 5
    @https.ca_path = '/etc/ssl/certs' if File.exists? '/etc/ssl/certs'  # Ubuntu
  end

  def core_form_data
    { :appID => 'swa', :appver => '2.17.0', :channel => 'wap', :platform => 'thinclient', :cacheid => '', :rcid => 'spaiphone' }
  end

  def fetch_trip_info(conf, first_name, last_name)
    request = Net::HTTP::Post.new '/middleware/MWServlet'
    request.set_form_data core_form_data.merge(
      :serviceID => 'viewAirReservation',
      :confirmationNumber => conf,
      :confirmationNumberFirstName => first_name,
      :confirmationNumberLastName => last_name,
      :searchType => 'ConfirmationNumber'
    )
    response = fetch request
    json = parse_json response
    @config.save_file conf, 'viewAirReservation.json', json.pretty_inspect
    json
  end

  def parse_json(response)
    if response.body == nil || response.body == ''
      @config.log "Empty response body returned"
      @config.log response
      return {}
    end
    JSON.parse response.body
  end

  def extract_conf(regex, *str)
    str.find { |s| s =~ regex }
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

  def extract_flights(info, leg_name, leg_type, previous_date = nil)
    leg_info = info[leg_name]
    return [] unless leg_info

    depart_code = extract_code leg_info["departCity"]
    depart_airport = Southy::Airport.lookup depart_code
    unless depart_airport
      @config.log "Unknown airport code: #{depart_code}"
      return []
    end

    passengers = info.map { |key, value| key =~ /^passengerName/ ? info[key] : nil }.compact

    passengers.map do |passenger|
      date = previous_date || leg_info["#{leg_type}Date"]
      time = extract_time leg_info["departCity"]
      local = DateTime.parse "#{date} #{time}"
      fname = info['chkinfirstName'] || info['ebchkinfirstName']
      lname = info['chkinlastName'] || info['ebchkinlastName']

      flight = Southy::Flight.new
      if passenger.downcase == "#{fname} #{lname}".downcase
        flight.first_name = fname.split(' ').map {|n| n.capitalize}.join(' ')
        flight.last_name = lname.split(' ').map {|n| n.capitalize}.join(' ')
      else
        flight.full_name = passenger
      end
      flight.confirmation_number = extract_conf(/^\w{6}$/, info['ebchkinConfNo'], info['cnclConfirmNo'], info['chgConfirmNo'])
      flight.number = leg_info["#{leg_type}FlightNo"]
      flight.depart_code = extract_code leg_info["departCity"]
      flight.depart_airport = extract_airport leg_info["departCity"]
      flight.arrive_code = extract_code leg_info["arrivalCity"]
      flight.arrive_airport = extract_airport leg_info["arrivalCity"]
      flight.depart_date = Southy::Flight.utc_date_time(local, flight.depart_code)
      flight
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

  def lookup(conf, first_name, last_name)
    json = fetch_trip_info conf, first_name, last_name
    errmsg = json['errmsg']

    if errmsg && errmsg != ''
      alternate_names(first_name, last_name).tap do |alt_first, alt_last|
        if alt_first != first_name || alt_last != last_name
          json = fetch_trip_info conf, alt_first, alt_last
          errmsg = json['errmsg']
        end
      end
    end

    if errmsg && errmsg != ''
      ident = "#{conf} #{first_name} #{last_name}"
      return { error: 'cancelled', flights: [] } if errmsg =~ /SW107028/
      return { error: 'invalid', flights: [] } if errmsg =~ /SW107023/

      if json['opstatus'] != 0
        @config.log "Technical error looking up flights for #{ident}"
        @config.log "  #{errmsg}"
        return { error: 'unknown', flights: [] }
      end

      @config.log "Unknown error looking up flights for #{ident}"
      @config.log "  #{errmsg}"
      return { error: 'unknown', flights: [] }
    end

    infos = json['upComingInfo']
    return { error: 'failure', flights: [] } unless infos
    response = { error: nil, flights: {} }
    infos.each do |info|
      infoConf = info['ebchkinConfNo'] || info['cnclConfirmNo']
      flights = []

      depart1 = extract_flights info, 'Depart1', 'depart'
      flights += depart1
      (2..5).each do |i|
        flights += extract_flights info, "Depart#{i}", 'depart', depart1[0].depart_date
      end if depart1.length > 0

      return1 = extract_flights info, 'Return1', 'return'
      flights += return1
      (2..5).each do |i|
        flights += extract_flights info, "Return#{i}", 'return', return1[0].depart_date
      end if return1.length > 0

      response[:flights][infoConf] = flights
    end

    response
  end

  def fetch_checkin_info(conf, first_name, last_name)
    request = Net::HTTP::Post.new '/middleware/MWServlet'
    request.set_form_data core_form_data.merge(
      :serviceID => 'flightcheckin_new',
      :recordLocator => conf,
      :firstName => first_name,
      :lastName => last_name
    )
    response = fetch request
    json = parse_json response
    @config.save_file conf, 'flightcheckin_new.json', json.pretty_inspect
    json
  end

  def checkin(flights)
    @cookies = []
    flight = flights[0]

    request = Net::HTTP::Post.new '/middleware/MWServlet'
    request.set_form_data core_form_data.merge(
      :serviceID => 'getTravelInfo'
    )
    response = fetch request
    json = parse_json response
    @config.save_file flight.conf, 'getTravelInfo.json', json.pretty_inspect

    json = fetch_checkin_info flight.confirmation_number, flight.first_name, flight.last_name
    output = json['output']

    unless output && output.length > 0 && output.any? { |o| o['flightNumber'] == flight.number }
      alternate_names(flight.first_name, flight.last_name).tap do |alt_first, alt_last|
        if alt_first != flight.first_name || flight.alt_last != last_name
          json = fetch_checkin_info flight.confirmation_number, alt_first, alt_last
          output = json['output']
        end
      end
    end

    unless output && output.length > 0 && output.any? { |o| o['flightNumber'] == flight.number }
      return { :flights => [] }
    end

    request = Net::HTTP::Post.new '/middleware/MWServlet'
    request.set_form_data core_form_data.merge(
      :serviceID => 'getallboardingpass'
    )
    response = fetch request
    json = parse_json response
    @config.save_file flight.conf, 'getallboardingpass.json', json.pretty_inspect
    docs = json['Document'].concat json['mbpPassenger']
    checked_in_flights = docs.map do |doc|
      d_flight_num = doc['flight_num'] || ''
      d_full_name  = ( doc['name']       || '' ).downcase
      d_first_name = ( doc['firstName']  || '' ).downcase
      d_last_name  = ( doc['lastName']   || '' ).downcase
      flight = flights.find do |f|
        d_flight_num == f.number &&
          ( d_full_name == '' || d_full_name == f.full_name.downcase ||
            ( d_first_name == f.first_name.downcase && d_last_name == f.last_name.downcase ) )
      end
      if flight
        flight.group = doc['boardingroup_text']
        flight.position = "#{doc['position1_text']}#{doc['position2_text']}".to_i
      end
      flight
    end

    @cookies = []
    { :flights => checked_in_flights.compact }
  end

  private

  def fetch(request)
    puts "Fetch #{request.path}" if DEBUG
    request['User-Agent'] = 'Mozilla/5.0 (iPhone; CPU iPhone OS 8_0 like Mac OS X) AppleWebKit/600.1.3 (KHTML, like Gecko) Version/8.0 Mobile/12A4345d Safari/600.1.4'

    restore_cookies request
    response = @https.request(request)
    save_cookies response

    response
  end

  def restore_cookies(request)
    request['Cookie'] = @cookies.join('; ') if @cookies.length
  end

  def save_cookies(response)
    cookie_headers = response.get_fields('Set-Cookie') || []
    cookie_headers.each do |c|
      @cookies << c.split(';')[0]
    end
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
