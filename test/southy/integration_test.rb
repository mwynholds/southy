require 'test_helper'

module Southy
  class IntegrationTest < MiniTest::Spec

    describe "Integration tests" do

      before do
        clean_db
      end

      describe "Single passenger, single bound, no stops" do
        before do
          agent.confirm "LNK23P", "Dimas", "Guardado"
          @reservations = Reservation.where confirmation_number: "LNK23P"
        end

        it "adds the right flights" do
          expect(@reservations.length).must_equal 1
          expect(@reservations.first.bounds.length).must_equal 1
          expect_reservation @reservations.first, conf: "LNK23P", email: nil
          expect_passengers  @reservations.first, "Dimas Guardado"
          expect_bound       @reservations.first.bounds.first, departure: "LAX 2019-06-07 21:50", arrival: "SJC 2019-06-07 22:55", flights: [ 1331 ]
          expect_stops       @reservations.first.bounds.first.stops
        end

      end

      describe "Multiple passengers, single bound, single stop" do
        before do
          agent.confirm "J9MZME", "Don", "Thompson"
          @reservations = Reservation.where confirmation_number: "J9MZME"
        end

        it "adds the right flights" do
          expect(@reservations.length).must_equal 1
          expect(@reservations.first.bounds.length).must_equal 1
          expect_reservation @reservations.first, conf: "J9MZME", email: nil
          expect_passengers  @reservations.first, "Donald L Thompson", "West Thompson"
          expect_bound       @reservations.first.bounds.first, departure: "TUS 2019-06-26 19:10", arrival: "SFO 2019-06-26 23:45", flights: [ 960, 543 ]
          expect_stops       @reservations.first.bounds.first.stops, "LAS 2019-06-26 20:25"
        end
      end

      describe "Multiple passengers, multiple bounds, no stops" do
        before do
          agent.confirm "LALAGH", "Max", "Holder", "max@carbonfive.com"
          @reservations = Reservation.where confirmation_number: "LALAGH"
          @reservations = @reservations.map { |r| agent.checkin r.bounds.first, force: true }
        end

        it "adds the right flights" do
          expect(@reservations.length).must_equal 1
          expect(@reservations.first.bounds.length).must_equal 2
          expect_reservation @reservations.first, conf: "LALAGH", email: "max@carbonfive.com"
          expect_passengers  @reservations.first, "Clay Campbell Smalley", "Maxwell Hanson Holder"
          expect_bound       @reservations.first.bounds.first, departure: "OAK 2019-06-01 08:20", arrival: "AUS 2019-06-01 13:45", flights: [ 4963 ]
          expect_stops       @reservations.first.bounds.first.stops
          expect_bound       @reservations.first.bounds.last, departure: "AUS 2019-06-03 11:50", arrival: "OAK 2019-06-03 13:45", flights: [ 993 ]
          expect_stops       @reservations.first.bounds.last.stops
        end

        it "gets the right seats" do
          expect_seats       @reservations.first.bounds.first, "Maxwell Hanson Holder" => "B04", "Clay Campbell Smalley" => "B03"
          expect_seats       @reservations.first.bounds.second, "Maxwell Hanson Holder" => "A55", "Clay Campbell Smalley" => "A54"
        end
      end
    end
  end
end
