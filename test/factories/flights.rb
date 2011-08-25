require 'date'

FactoryGirl.define do

  sequence :conf do |n|
    n.to_s.rjust 6, 'A'
  end

  factory :flight, :class => Southy::Flight do |flight|
    flight.confirmation_number Factory.next(:conf)
    flight.first_name          'First'
    flight.last_name           'Last'
  end

  factory :confirmed_flight, :parent => :flight do |flight|
    flight.number         '1234'
    flight.depart_date     DateTime.parse '01/01/2011'
    flight.depart_airport 'LAX'
    flight.arrive_airport 'SFO'
  end

end

