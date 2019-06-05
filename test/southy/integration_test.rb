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
    end
  end
end
