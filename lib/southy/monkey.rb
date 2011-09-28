require 'nokogiri'
require 'net/https'
require 'fileutils'

class Southy::Monkey

  def initialize
    @http = Net::HTTP.new 'www.southwest.com'
    #@http = Net::HTTP.new 'localhost', 9000
    @https = Net::HTTP.new 'www.southwest.com', 443
    @https.use_ssl = true

    certs = File.join File.dirname(__FILE__), "../../etc/certs"
    if (File.directory? certs)
      @https.ca_path = certs
      @https.verify_mode = OpenSSL::SSL::VERIFY_PEER
      @https.verify_depth = 5
    else
      @https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
  end

  def lookup(conf, first_name, last_name)
    request = Net::HTTP::Post.new '/flight/view-air-reservation.html'
    request.set_form_data :confirmationNumber => conf,
                          :confirmationNumberFirstName => first_name,
                          :confirmationNumberLastName => last_name
    _, response = fetch({}, request, true)

    doc = Nokogiri::HTML response.body
    legs = []
    doc.css('.itinerary_container').each do |container_node|
      container_node.css('.airProductItineraryTable').each do |table_node|
        leg_nodes = table_node.css('tr.whiteRow') + table_node.css('tr.grayRow')
        leg_nodes.each do |leg_node|
          legs << Southy::Flight.new.apply_confirmation(container_node, leg_node)
        end
      end
    end
    legs
  end

  def checkin(flight)
    all_cookies = {}

    request = Net::HTTP::Get.new '/flight/retrieveCheckinDoc.html?forceNewSession=yes'
    _, _ = fetch all_cookies, request

    request = Net::HTTP::Post.new '/flight/retrieveCheckinDoc.html'
    request['Referer'] = 'http://www.southwest.com/flight/retrieveCheckinDoc.html?forceNewSession=yes'
    request.set_form_data :confirmationNumber => flight.confirmation_number,
                          :firstName => flight.first_name,
                          :lastName => flight.last_name,
                          :submitButton => 'Check In'
    referer, response = fetch all_cookies, request

    doc = Nokogiri::HTML response.body
    checkin_options = doc.css '#checkinOptions'
    return nil unless checkin_options

    request = Net::HTTP::Post.new '/flight/selectPrintDocument.html'
    data = { :printDocuments => 'Check In' }
    checkin_options.css('.passengerRow').each_with_index do |_, i|
      data["_checkinPassengers[#{i}].selected"] = 'on'
      data["checkinPassengers[#{i}].selected"] = 'true'
    end
    request['Referer'] = referer
    request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:6.0.1) Gecko/20100101 Firefox/6.0.1'
    request.set_form_data data
    _, response = fetch all_cookies, request

    doc = Nokogiri::HTML response.body
    checkin_docs = doc.css '.checkinDocument'
    return nil unless checkin_docs.length > 0

    flights = []
    checkin_docs.each do |node|
      flights << flight.dup.apply_checkin(node)
    end

    flights
  end

  private

  def fetch(all_cookies, request, https = false)
    set_cookies all_cookies, request
    response = https ? @https.request(request) : @http.request(request)
    grab_cookies all_cookies, response

    location = nil
    while response.is_a? Net::HTTPRedirection
      location = response['Location']
      path = location.sub /^https?:\/\/[^\/]+/, ''
      request = Net::HTTP::Get.new path
      set_cookies all_cookies, request
      if location =~ /^https:/
        response = @https.request request
      else
        response = @http.request request
      end
      grab_cookies all_cookies, response
    end

    [location, response]
  end

  def set_cookies(all_cookies, request)
    request['Cookie'] = all_cookies.values.join('; ') if all_cookies.length > 0
  end

  def grab_cookies(all_cookies, response)
    cookies = response.get_fields 'Set-Cookie'
    if cookies
      cookies.each do |c|
        name = c.match(/^([^=]+)=/)[1]
        all_cookies[name] = c.split(';')[0]
      end
    end
  end
end

class Southy::TestMonkey
  def lookup(conf, first_name, last_name)
    date = DateTime.now + rand(20) + 1
    [ Southy::Flight.new(:first_name => first_name, :last_name => last_name, :confirmation_number => conf,
                         :number => 123, :depart_date => date, :depart_airport => 'LAX', :arrive_airport => 'SFO') ]
  end

  def checkin(flight)
    flight.group = %w(A B C)[rand(3)]
    flight.position = rand(60) + 1
    [ flight ]
  end
end