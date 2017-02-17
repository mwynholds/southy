require 'date'

FactoryGirl.define do

  sequence :conf do |n|
    n.to_s.rjust 6, 'A'
  end

  factory :unconfirmed_flight, :class => Southy::Flight do |flight|
    flight.confirmation_number FactoryGirl.generate(:conf)
    flight.first_name          'First'
    flight.last_name           'Last'
  end

  factory :confirmed_flight, :parent => :unconfirmed_flight do |flight|
    flight.number         '1234'
    flight.depart_date     DateTime.parse '01/01/2015'
    flight.depart_airport 'LAX'
    flight.arrive_airport 'SFO'
  end

end

