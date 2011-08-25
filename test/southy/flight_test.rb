require 'test_helper'

class Southy::FlightTest < MiniTest::Spec
  describe 'Flight' do
    describe '#confirmed?' do
      before do
        @unconfirmed = Factory.build :flight
        @confirmed = Factory.build :confirmed_flight
      end

      it 'detects unconfirmed flights' do
        @unconfirmed.confirmed?.must_equal false
      end

      it 'detects confirmed flights' do
        @confirmed.confirmed?.must_equal true
      end
    end

    describe '#checkinable?' do

    end
  end
end