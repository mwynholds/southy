require 'tmpdir'
require 'yaml'

class Southy::Config
  attr_reader :config, :flights, :pid_file

  def initialize(config_dir = nil)
    @dir = config_dir || "#{ENV['HOME']}/.southy"
    FileUtils.mkdir @dir unless File.directory? @dir

    @pid_file = "#{@dir}/pid"

    @timestamps = {}
    load_config :force => true
    load_flights :force => true
  end

  def init(first_name, last_name, email = nil)
    @config = {:first_name => first_name, :last_name => last_name, :email => email}
    File.open config_file, "w" do |f|
      f.write(@config.to_yaml)
    end
  end

  def add(conf, first_name = nil, last_name = nil, email = nil)
    flight = Southy::Flight.new
    flight.confirmation_number = conf.upcase.gsub(/0/, 'O')
    flight.first_name = first_name || @config[:first_name]
    flight.last_name = last_name || @config[:last_name]
    flight.email = email || @config[:email]

    @flights << flight

    File.open flights_file, 'a' do |f|
      f.write flight.to_csv
    end
  end

  def confirm(flight)
    @flights.delete_if { |f| f.confirmation_number == flight.confirmation_number and ! f.confirmed? }
    @flights << flight
    dump_flights
  end

  def checkin(flight)
    @flights.delete_if do |f|
      f.confirmation_number == flight.confirmation_number &&
      f.number == flight.number &&
      f.depart_date == flight.depart_date &&
      f.full_name == flight.full_name
    end
    @flights << flight
    dump_flights
  end

  def remove(conf)
    @flights.delete_if { |flight| flight.confirmation_number == conf.upcase.gsub(/0/, 'O') }
    dump_flights
  end

  def unconfirmed
    @flights.select { |f| ! f.confirmed? }
  end

  def upcoming
    @flights.select { |f| f.confirmed? && f.depart_date > DateTime.now }
  end

  def past
    @flights.select { |f| f.confirmed? && f.depart_date <= DateTime.now }
  end

  def list
    puts 'Upcoming Southwest flights:'
    Southy::Flight.list upcoming
    Southy::Flight.list unconfirmed
  end

  def history
    puts 'Previous Southwest flights:'
    Southy::Flight.list past
  end

  def reload(options = {})
    options = { :force => false }.merge options
    load_config options
    load_flights options
  end

  private

  def load_config(options)
    @config = if_updated? config_file, options do
      YAML.load( IO.read(config_file) )
    end
    @config ||= {}
  end

  def load_flights(options)
    @flights = if_updated? flights_file, options do
      IO.read(flights_file).split("\n").map {|line| Southy::Flight.from_csv(line)}
    end
    @flights ||= []
  end

  def dump_flights
    @flights.sort!
    File.open flights_file, 'w' do |f|
      @flights.each do |flight|
        f.write flight.to_csv
      end
    end
  end

  def config_file
    "#{@dir}/config.yml"
  end

  def flights_file
    "#{@dir}/flights.csv"
  end

  def if_updated?(file_name, options)
    return nil if ! File.exists? file_name

    file = File.new file_name
    last_read = @timestamps[file_name]
    stamp = file.mtime
    if options[:force] || last_read.nil? || stamp > last_read
      yield
    else
      nil
    end
  end
end