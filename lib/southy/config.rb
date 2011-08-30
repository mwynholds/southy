require 'tmpdir'
require 'yaml'

class Southy::Config
  attr_reader :config, :upcoming, :pid_file

  def initialize(config_dir = nil)
    @dir = config_dir || "#{ENV['HOME']}/.southy"
    FileUtils.mkdir @dir unless Dir.exists? @dir

    @pid_file = "#{@dir}/pid"

    @timestamps = {}
    load_config :force => true
    load_upcoming :force => true
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

    @upcoming << flight

    File.open upcoming_file, 'a' do |f|
      f.write flight.to_csv
    end
  end

  def confirm(flight)
    @upcoming.delete_if { |f| f.confirmation_number == flight.confirmation_number and ! f.confirmed? }
    @upcoming << flight
    dump_upcoming
  end

  def remove(conf)
    @upcoming.delete_if { |flight| flight.confirmation_number == conf.upcase.gsub(/0/, 'O') }
    dump_upcoming
  end

  def list
    puts "Upcoming Southwest flights:"
    Southy::Flight.list @upcoming
  end

  def history
    puts 'History is not yet implemented'
  end

  def reload(options = {})
    options = { :force => false }.merge options
    load_config options
    load_upcoming options
  end

  private

  def load_config(options)
    @config = if_updated? config_file, options do
      YAML.load( IO.read(config_file) )
    end
    @config ||= {}
  end

  def load_upcoming(options)
    @upcoming = if_updated? upcoming_file, options do
      IO.read(upcoming_file).split("\n").map {|line| Southy::Flight.from_csv(line)}
    end
    @upcoming ||= []
  end

  def dump_upcoming
    @upcoming.sort!
    File.open upcoming_file, 'w' do |f|
      @upcoming.each do |flight|
        f.write flight.to_csv
      end
    end
  end

  def config_file
    "#{@dir}/config.yml"
  end

  def upcoming_file
    "#{@dir}/upcoming"
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