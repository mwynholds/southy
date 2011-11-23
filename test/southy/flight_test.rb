require 'test_helper'

class Southy::Flight
  class << self
    alias_method :utc_alias, :utc_date_time
    def utc_date_time(local, code)
      utc_alias(local, code)
    end

    alias_method :local_alias, :local_date_time
    def local_date_time(utc, code)
      local_alias(utc, code)
    end
  end
end

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
        @past = Factory.build :confirmed_flight, :depart_date => DateTime.now - 1.0/24
        @distant = Factory.build :confirmed_flight, :depart_date => DateTime.now + 25.0/24
        @soon = Factory.build :confirmed_flight, :depart_date => DateTime.now + 12.0/24
        @justbarely = Factory.build :confirmed_flight, :depart_date => DateTime.now + 1 + 2.0/(24*60)
        @justbarelynot = Factory.build :confirmed_flight, :depart_date => DateTime.now + 1 + 3.0/(24*60)
      end

      it 'rejects unconfirmed flights' do
        @unconfirmed.checkin_available?.must_equal false
      end

      it 'rejects past flights' do
        @past.checkin_available?.must_equal false
      end

      it 'rejects distant future flights' do
        @distant.checkin_available?.must_equal false
      end

      it 'accepts upcoming flights' do
        @soon.checkin_available?.must_equal true
      end

      it 'accepts flights 2 minutes early' do
        @justbarely.checkin_available?.must_equal true
        @justbarelynot.checkin_available?.must_equal false
      end

    end

    describe '#utc_date_time' do
      it 'handles different time zones' do
        local = DateTime.parse '2000-02-01T02:00:00'
        Southy::Flight.utc_date_time(local, 'SFO').to_s.must_equal('2000-02-01T10:00:00+00:00')
        Southy::Flight.utc_date_time(local, 'LGA').to_s.must_equal('2000-02-01T07:00:00+00:00')
      end

      it 'handles daylight savings time' do
        local = DateTime.parse '2000-08-01T02:00:00'
        Southy::Flight.utc_date_time(local, 'SFO').to_s.must_equal('2000-08-01T09:00:00+00:00')
        Southy::Flight.utc_date_time(local, 'LGA').to_s.must_equal('2000-08-01T06:00:00+00:00')
      end
    end

    describe '#local_date_time' do
      it 'handles different time zones' do
        utc = DateTime.parse '2000-02-01T10:00:00'
        Southy::Flight.local_date_time(utc, 'SFO').to_s.must_equal('2000-02-01T02:00:00-08:00')
        Southy::Flight.local_date_time(utc, 'LGA').to_s.must_equal('2000-02-01T05:00:00-05:00')
      end

      it 'handles daylight savings time' do
        utc = DateTime.parse '2000-08-01T10:00:00'
        Southy::Flight.local_date_time(utc, 'SFO').to_s.must_equal('2000-08-01T03:00:00-07:00')
        Southy::Flight.local_date_time(utc, 'LGA').to_s.must_equal('2000-08-01T06:00:00-04:00')
      end
    end
  end
end
