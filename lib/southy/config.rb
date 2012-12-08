require 'yaml'
require 'time'

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

  def smtp_host
    @config[:smtp_host]
  end

  def smtp_port
    @config[:smtp_port]
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
    @flights << flight unless @flights.any? do |f|
      f.confirmation_number == flight.confirmation_number &&
      f.number == flight.number &&
      f.depart_date == flight.depart_date &&
      f.full_name == flight.full_name
    end
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

  def remove(conf, first_name = nil, last_name = nil)
    @flights.delete_if do |flight|
      flight.confirmation_number == conf.upcase.gsub(/0/, 'O') &&
              ( first_name.nil? || flight.first_name.downcase == first_name.downcase ) &&
              ( last_name.nil?  || flight.last_name.downcase == last_name.downcase )
    end
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

  def list(options = {})
    flights = filter upcoming + unconfirmed, options[:filter]
    puts 'Upcoming Southwest flights:'
    Southy::Flight.list flights, options
  end

  def history(options = {})
    flights = filter past, options[:filter]
    puts 'Previous Southwest flights:'
    Southy::Flight.list flights, options
  end

  def filter(flights, filter = nil)
    return flights unless filter
    filter.downcase!
    flights.select do |flight|
      flight.email.downcase == filter || flight.confirmation_number.downcase == filter ||
        flight.full_name_with_email.downcase.include?(filter)
    end
  end

  def prune
    past_flights = past
    past_flights.each do |flight|
      remove flight.conf
    end

    n = past_flights.length
    puts "Removed #{n} flight#{n == 1 ? '' : 's'}."
  end

  def reload(options = {})
    options = { :force => false }.merge options
    load_config options
    load_flights options
  end

  def log(msg, ex = nil)
    log = File.new(log_file, 'a')
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    type = ex ? 'ERROR' : ' INFO'
    log.puts "#{type}  #{timestamp}  #{msg}"
    if ex
      log.puts ex.message
      log.puts ex.backtrace.join("\n")
    end
  end

  def save_file(conf, name, contents)
    saved_files = saved_files_dir
    FileUtils.mkdir saved_files unless File.directory? saved_files
    itinerary_dir = "#{saved_files}/#{conf}"
    FileUtils.mkdir itinerary_dir unless File.directory? itinerary_dir

    File.open("#{itinerary_dir}/#{name}", 'w') do |f|
      f.print contents
    end
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
    @flights.sort!
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

  def log_file
    "#{@dir}/southy.log"
  end

  def saved_files_dir
    "#{@dir}/saved_files"
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
