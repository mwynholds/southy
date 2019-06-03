require 'csv'

module Southy
  class Airport

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
      Airport.load_airports if @@airports.empty?
      @@airports.each do |code, airport|
        puts "#{code} -> #{airport}"
      end
    end

    def self.lookup(code)
      Airport.load_airports if @@airports.empty?
      @@airports[code]
    end

    def self.validate(code)
      raise SouthyException.new("Unknown airport: #{code}") unless lookup code
    end

    def self.all
      Airport.load_airports if @@airports.empty?
      @@airports.values
    end

    def timezone
      (@@codes[code] || @@offsets[tz_offset]) or raise "Unknown timezone offset: #{self.name} (#{self.code}): #{tz_offset}"
    end

    def ident
      "#{name} (#{code})"
    end

    def to_s
      "#{name} (#{code}): #{tz_offset} #{timezone}"
    end

    def local_time(date, time = nil)
      tz      = TZInfo::Timezone.get timezone
      utc     = time ? tz.local_to_utc(DateTime.parse("#{date} #{time}")) : date
      local   = tz.utc_to_local utc
      offset  = tz.period_for_local(local).utc_total_offset / (60 * 60)

      DateTime.parse( local.to_s.sub('+00:00', "#{offset}:00") )
    end

    private

    def self.load_airports
      datafile = __dir__ + "/../data/swa-airports.dat"
      File.open(datafile, 'r') do |file|
        file.readlines.each do |line|
          unless line.strip.empty?
            pieces = line.parse_csv
            airport = Airport.new
            airport.name = pieces[1]
            airport.code = pieces[4]
            airport.tz_offset = pieces[9]
            @@airports[airport.code] = airport
          end
        end
      end
    end

  end
end
