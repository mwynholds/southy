require 'test_helper'

class Southy::FlightTest < MiniTest::Spec
  describe 'Flight' do
    describe '#confirmed?' do
      before do
        @unconfirmed = Factory.build :unconfirmed_flight
        @confirmed = Factory.build :confirmed_flight
      end

      it 'detects unconfirmed flights' do
        @unconfirmed.confirmed?.must_equal false
      end

      it 'detects confirmed flights' do
        @confirmed.confirmed?.must_equal true
      end
    end

    describe '#checkin_available?' do
      before do
        @unconfirmed = Factory.build :unconfirmed_flight
        @past = Factory.build :confirmed_flight, :depart_date => DateTime.now - 1 * 60 * 60
        @unavailable = Factory.build :confirmed_flight, :depart_date => DateTime.now + 25 * 60 * 60
        @available = Factory.build :confirmed_flight, :depart_date => DateTime.now + 12 * 60 * 60
      end

      it 'rejects unconfirmed flights' do
        @unconfirmed.checkin_available?.must_equal false
      end

      it 'rejects past flights' do
        @past.checkin_available?.must_equal false
      end

      it 'rejects distant future flights' do
        @unavailable.checkin_available?.must_equal false
      end

      it 'accepts upcoming flights' do
        @available.checkin_available?.must_equal true
      end

    end
  end
end