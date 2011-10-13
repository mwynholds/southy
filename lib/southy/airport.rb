require 'csv'

class Southy::Airport

  @@offsets = {
          '-11' => 'America/Adak',
          '-10' => 'Pacific/Honolulu',
          '-9'  => 'America/Juneau',
          '-8'  => 'America/Los_Angeles',
          '-7'  => 'America/Denver',
          '-6'  => 'America/Chicago',
          '-5'  => 'America/New_York'
  }
  @@codes = {
          'PHX' => 'America/Phoenix',
          'TUS' => 'America/Phoenix'
  }
  @@airports = {}

  attr_accessor :name, :code, :tz_offset

  def self.dump
    Southy::Airport.load_airports if @@airports.empty?
    @@airports.each do |code, airport|
      puts "#{code} -> #{airport}"
    end
  end

  def self.lookup(code)
    Southy::Airport.load_airports if @@airports.empty?
    @@airports[code]
  end

  def self.all
    Southy::Airport.load_airports if @@airports.empty?
    @@airports.values
  end

  def timezone
    (@@codes[code] || @@offsets[tz_offset]) or raise "Unknown timezone offset: #{self.name} (#{self.code}): #{tz_offset}"
  end

  def to_s
    "#{name} (#{code}): #{tz_offset} #{timezone}"
  end

  private

  def self.load_airports
    datafile = File.dirname(__FILE__) + "/swa-airports.dat"
    File.open(datafile, 'r') do |file|
      file.readlines.each do |line|
        unless line.strip.empty?
          pieces = line.parse_csv
          airport = Southy::Airport.new
          airport.name = pieces[1]
          airport.code = pieces[4]
          airport.tz_offset = pieces[9]
          @@airports[airport.code] = airport
        end
      end
    end
  end

end
