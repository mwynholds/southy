require 'test_helper'
require 'fileutils'
require 'yaml'

class Southy::ConfigTest < MiniTest::Spec

  module Helpers
    def flights
      IO.read "#{@config_dir}/flights.csv"
    end

    def config
      IO.read "#{@config_dir}/config.yml"
    end

    def populate
      File.open "#{@config_dir}/flights.csv", 'w' do |file|
        file.puts "AA,F,L"
        file.puts "BB,F,L"
        file.puts "CC,F,L,,1,#{DateTime.now + 2},LAX,SFO"
        file.puts "DD,F,L,,1,#{DateTime.now + 1},LAX,SFO"
        file.puts "EE,F,L,,1,#{DateTime.now - 1},LAX,SFO"
        file.puts "FF,F,L,,1,#{DateTime.now - 2},LAX,SFO"
      end
      @config.reload
    end
  end

  describe 'Config' do

    before do
      @config_dir = "#{File.dirname(__FILE__)}/../../.config_test_#{rand 1000}"
      FileUtils.remove_entry_secure @config_dir if Dir.exists? @config_dir
      @config = Southy::Config.new @config_dir
      extend Helpers
    end

    describe '#init' do
      before do
        @config.init 'First', 'Last', 'flast@internet.com'
      end

      it 'adds the name' do
        config.must_equal({ :first_name => 'First', :last_name => 'Last', :email => 'flast@internet.com' }.to_yaml)
      end
    end

    describe '#add' do
      describe 'not initialized' do
        describe 'with name' do
          before do
            @config.add 'ABCDEF', 'First', 'Last'
            @config.add 'GHIJKL', 'One', 'Two', 'otwo@internet.com'
          end
          it 'adds the flight' do
            flights.must_equal "ABCDEF,First,Last\nGHIJKL,One,Two,otwo@internet.com\n"
          end
        end
      end

      describe 'initialized without email' do
        describe 'with name' do
          before do
            @config.init 'First', 'Last'
            @config.add 'ABCDEF', 'One', 'Two'
          end
          it 'adds the flight' do
            flights.must_equal "ABCDEF,One,Two\n"
          end
        end

        describe 'without name' do
          before do
            @config.init 'First', 'Last'
            @config.add 'ABCDEF'
          end
          it 'adds the flight' do
            flights.must_equal "ABCDEF,First,Last\n"
          end
        end
      end

      describe 'initialized with email' do
        describe 'with name' do
          before do
            @config.init 'First', 'Last', 'flast@internet.com'
            @config.add 'ABCDEF', 'One', 'Two'
          end
          it 'adds the flight' do
            flights.must_equal "ABCDEF,One,Two,flast@internet.com\n"
          end
        end

        describe 'without name' do
          before do
            @config.init 'First', 'Last', 'flast@internet.com'
            @config.add 'ABCDEF'
          end
          it 'adds the flight' do
            flights.must_equal "ABCDEF,First,Last,flast@internet.com\n"
          end
        end
      end
    end

    describe '#remove' do
      before do
        @config.add 'ABCDEF', 'First', 'Last'
        @config.add 'GHIJKL', 'One', 'Two'
        @config.remove 'ABCDEF'
      end
      it 'removes the flight' do
        flights.must_equal "GHIJKL,One,Two\n"
      end
    end

    describe '#confirm' do
      before do
        @config.add 'ABCDEF', 'First', 'Last'
        @config.add 'GHIJKL', 'First', 'Last'
        @config.confirm( Factory.build :confirmed_flight, :confirmation_number => 'ABCDEF' )
      end

      it 'updates the flight' do
        flights.must_equal "ABCDEF,First,Last,,1234,2015-01-01T00:00:00+00:00,LAX,,SFO\nGHIJKL,First,Last\n"
      end
    end

    describe '#unconfirmed' do
      it 'returns unconfirmed flights' do
        populate
        @config.unconfirmed.map(&:confirmation_number).must_equal ['AA', 'BB']
      end
    end

    describe '#upcoming' do
      it 'returns upcoming flights' do
        populate
        @config.upcoming.map(&:confirmation_number).must_equal ['DD', 'CC']
      end
    end

    describe '#past' do
      it 'returns past flights' do
        populate
        @config.past.map(&:confirmation_number).must_equal ['FF', 'EE']
      end
    end

    describe '#filter' do
      before do
        @config.add 'AA', 'Uno', 'Hombre', 'one@carbonfive.com'
        @config.add 'BB', 'Dos', 'Hombre', 'two@carbonfive.com'
      end
      it 'filters flights by email' do
        filtered = @config.filter @config.unconfirmed, 'one@carbonfive.com'
        filtered.map(&:confirmation_number).must_equal ['AA']
      end
      it 'filters flights by name' do
        filtered = @config.filter @config.unconfirmed, 'uno'
        filtered.map(&:confirmation_number).must_equal ['AA']

        filtered = @config.filter @config.unconfirmed, 'hombre'
        filtered.map(&:confirmation_number).must_equal ['AA', 'BB']
      end
      it 'filters flights by confirmation number' do
        filtered = @config.filter @config.unconfirmed, 'bb'
        filtered.map(&:confirmation_number).must_equal ['BB']
      end
    end

    after do
      FileUtils.remove_entry_secure @config_dir if Dir.exists? @config_dir
    end

  end

end
