ENV['RUBY_ENV'] = 'test'

$LOAD_PATH << File.dirname(__FILE__) + "/../lib"
require 'southy'

require 'minitest/autorun'

def clean_db
  Southy::Seat.delete_all
  Southy::Stop.delete_all
  Southy::Bound.delete_all
  Southy::Passenger.delete_all
  Southy::Reservation.delete_all
end

def agent
  fixtures = "#{__dir__}/fixtures"
  monkey   = Southy::TestMonkey.new fixtures
  config   = Southy::Config.new
  agent    = Southy::TravelAgent.new config
  slackbot = Southy::Slackbot.new config, agent
  agent.monkey   = monkey
  agent.slackbot = slackbot

  agent
end

def parse_time(info)
  code = info[0..2]
  airport = Southy::Airport.lookup code
  time = airport.local_time info[4..-1]
  return code, time
end

def expect_reservation(reservation, conf:, email:)
  expect(reservation.conf).must_equal conf
  email ? expect(reservation.email).must_equal(email) : expect(reservation.email).must_be_nil
end

def expect_passengers(reservation, *names)
  expect(reservation.passengers.map(&:name).sort).must_equal names
end

def expect_bound(bound, departure:, arrival:, flights:)
  code, time = parse_time departure
  expect(bound.departure_airport.code).must_equal code
  expect(bound.departure_time).must_equal time

  code, time = parse_time arrival
  expect(bound.arrival_airport.code).must_equal code
  expect(bound.arrival_time).must_equal time

  expect(bound.flights).must_equal flights.map(&:to_s)
end

def expect_stops(stops, *infos)
  pieces = infos.map { |i| parse_time i }
  expect(stops.map(&:airport).map(&:code)).must_equal pieces.map(&:first)
  expect(stops.map(&:arrival_time)).must_equal pieces.map(&:last)
end

def expect_seats(bound, seats)
  seats.each do |name, seat|
    expect(bound.passengers.find { |p| p.name == name }.seats_ident_for(bound)).must_equal seat
  end
end
