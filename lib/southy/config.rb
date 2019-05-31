require 'yaml'
require 'time'
require 'thread'

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

  def flights_lock
    @lock ||= Mutex.new
  end

  def smtp_host
    @config[:smtp_host]
  end

  def smtp_port
    @config[:smtp_port]
  end

  def smtp_domain
    @config[:smtp_domain]
  end

  def smtp_account
    @config[:smtp_account]
  end

  def smtp_password
    @config[:smtp_password]
  end

  def slack_api_token
    @config[:slack_api_token]
  end

  def slack_reject_channels
    @config.fetch(:slack_reject_channels, '').split ','
  end

  def slack_accept_channels
    @config.fetch(:slack_accept_channels, '').split ','
  end

  def add(conf, first_name = nil, last_name = nil, email = nil)
    flight = @flights.find { |f| f.conf == conf }
    if flight
      return { error: "Confirmation #{conf} already exists" }
    end

    flight = Southy::Flight.new
    flight.confirmation_number = conf.upcase.gsub(/0/, 'O')
    flight.first_name = (first_name || @config[:first_name]).gsub '-', ' '
    flight.last_name = (last_name || @config[:last_name]).gsub '-', ' '
    flight.email = email || @config[:email]

    @flights << flight
    dump_flights
    {}
  end

  def confirm(flight)
    @flights.delete_if { |f| f.confirmation_number == flight.confirmation_number and ! f.confirmed? }
    @flights << flight unless @flights.any? { |f| f.matches_completely? flight }
    dump_flights
  end

  def checkin(flight)
    @flights.delete_if { |f| f.matches_completely? flight }
    @flights << flight
    dump_flights
  end

  def checkout(flight)
    existing = @flights.find { |f| f.matches_completely? flight }
    if existing
      existing.group = nil
      existing.position = nil
    end
    dump_flights
  end

  def remove(conf, first_name = nil, last_name = nil)
    @flights.delete_if do |flight|
      flight.confirmation_number == conf.upcase.gsub(/0/, 'O') &&
              ( first_name.nil? || flight.first_name.downcase == first_name.downcase ) &&
              ( last_name.nil?  || flight.last_name.downcase  == last_name.downcase  )
    end
    dump_flights
  end

  def remove_pending(conf)
    @flights.delete_if do |flight|
      flight.confirmation_number == conf.upcase.gsub(/0/, 'O') && !flight.checked_in?
    end
  end

  def find(conf)
    @flights.select { |f| f.conf == conf.strip }
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

  def checked_in
    @flights.select { |f| f.checked_in? && f.depart_date > DateTime.now }
  end

  def list(options = {})
    flights = filter upcoming + unconfirmed, options[:filter]
    Southy::Flight.sprint flights, options
  end

  def history(options = {})
    flights = filter past, options[:filter]
    Southy::Flight.sprint flights, options
  end

  def filter(flights, filter = nil)
    return flights unless filter
    f = filter.downcase
    flights.select do |flight|
      flight.email.downcase == f || flight.confirmation_number.downcase == f || flight.full_name.downcase.include?(f)
    end
  end

  def matches(flights)
    flights.all? do |flight|
      upcoming.any? { |f| f.matches_completely? flight }
    end
  end

  def prune
    past_flights = past
    past_flights.each do |flight|
      remove flight.conf
    end

    past_flights.length
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
      log.puts("Stacktrace:\n" + ex.backtrace.join("\n"))
    end
    log.flush
  end

  def save_file(conf, name, json)
    saved_files = saved_files_dir
    FileUtils.mkdir saved_files unless File.directory? saved_files
    itinerary_dir = "#{saved_files}/#{conf}"
    FileUtils.mkdir itinerary_dir unless File.directory? itinerary_dir

    iname = name
    i = 0
    while File.exist? "#{itinerary_dir}/#{iname}" do
      i += 1
      iname = "#{File.basename name, '.*'}_#{i}#{File.extname name}"
    end

    File.open("#{itinerary_dir}/#{iname}", 'w') do |f|
      f.print JSON.pretty_generate(json)
    end
  end

  private

  def load_config(options)
    config = if_updated? config_file, options do
      YAML.load( IO.read(config_file) )
    end
    @config = config if config
    @config ||= {}
  end

  def load_flights(options)
    flights = nil
    flights_lock.synchronize do
      flights = if_updated? flights_file, options do
        IO.read(flights_file).split("\n").map {|line| Southy::Flight.from_csv(line)}
      end
    end
    if flights
      @flights = flights || []
      @flights.sort!
    end
  end

  def dump_flights
    @flights.sort!
    flights_lock.synchronize do
      File.open flights_file, 'w' do |f|
        @flights.each do |flight|
          f.write flight.to_csv
        end
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
    return nil if ! File.exist? file_name

    file = File.new file_name
    last_read = @timestamps[file_name]
    stamp = file.mtime
    if options[:force] || last_read.nil? || stamp > last_read
      @timestamps[file_name] = stamp
      yield
    else
      nil
    end
  end
end
