require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'timecop'

class Southy::IntegrationTest < MiniTest::Spec
  EXPECTED =
          {
                  'WBWHS8' => { 1814 => { 'Robin Pak' => 'A31' },
                                2198 => { 'Robin Pak' => 'A49' },
                                1278 => { 'Robin Pak' => 'B26' } },
                  'IU6ITC' => { 2531 => { 'Candace Wynholds' => 'A25', 'Hans Wynholds' => 'A33' },
                                3411 => { 'Candace Wynholds' => 'B25', 'Hans Wynholds' => 'B33' } }#,
                  #'IBG773' => { 246  => { 'Lora Wynholds' => nil },
                  #              1827 => { 'Lora Wynholds' => nil } }
          }

  describe 'Itineraries' do

    EXPECTED.each do |conf, flights|
      describe "#{conf}" do
        before do
          @dir = Dir.mktmpdir "southy"
          config = Southy::Config.new @dir
          @agent = Southy::TravelAgent.new config, :test => true
          @agent.monkey.itinerary = conf
          name = flights.first[1].first[0].split
          flight_info = Southy::Flight.new :confirmation_number => conf, :first_name => name[0], :last_name => name[1]
          @confirmed = @agent.confirm flight_info
          @checked_in = []
          @confirmed.each do |c|
            Timecop.travel(c.depart_date - 1.0/2)
            @checked_in += @agent.checkin([c.dup])
            Timecop.return
          end
        end

        after do
          FileUtils.remove_entry_secure @dir
        end

        it 'confirms the flights' do
          total_flights = flights.reduce(0) { |total, (_, passengers)| total += passengers.length }
          @confirmed.length.must_equal total_flights
          flights.each do |num, passengers|
            f2 = @confirmed.select { |f| f.number == num.to_s }
            f2.length.must_equal passengers.length
            passengers.each do |name, seat|
              f3 = f2.select { |f| f.full_name == name }
              f3.length.must_equal 1
            end
          end
        end

        it 'checks in the flights' do
          total_flights = flights.reduce(0) { |total, (_, passengers)| total += passengers.length }
          @checked_in.length.must_equal total_flights
          flights.each do |num, passengers|
            f2 = @checked_in.select { |f| f.number == num.to_s }
            f2.length.must_equal passengers.length
            passengers.each do |name, seat|
              f3 = f2.select { |f| f.full_name == name }
              f3.length.must_equal 1
              f = f3[0]
              if seat.nil?
                f.seat.must_be_nil
              else
                f.seat.must_equal seat
              end
            end
          end
        end
      end
    end
  end
end