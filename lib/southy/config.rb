require 'tmpdir'
require 'yaml'

class Southy::Config
  def initialize(config_dir = nil)
    @config_dir = config_dir || Dir.mktmpdir
    FileUtils.mkdir @config_dir unless Dir.exists? @config_dir

    load_config
    load_upcoming
  end

  def init(first_name, last_name)
    @config = {:first_name => first_name, :last_name => last_name}
    File.open "#{@config_dir}/config", "w" do |f|
      f.write(@config.to_yaml)
    end
  end

  def add(conf, first_name = nil, last_name = nil)
    flight = Southy::Flight.new
    flight.confirmation_number = conf
    flight.first_name = first_name || @config[:first_name]
    flight.last_name = last_name || @config[:last_name]

    @upcoming << flight

    File.open "#{@config_dir}/upcoming", 'a' do |f|
      f.write flight.to_line + "\n"
    end
  end

  def remove(conf)
    @upcoming.delete_if { |flight| flight.confirmation_number == conf }
    dump_upcoming
  end

  private

  def load_config
    config_file = "#{@config_dir}/config"
    @config = YAML.load( IO.read(config_file) ) if File.exists? config_file
    @config ||= {}
  end

  def load_upcoming
    upcoming_file = "#{@config_dir}/upcoming"
    @upcoming = IO.open(upcoming_file).split("\n").map {|line| Southy::Flight.from_line(line)} if File.exists? upcoming_file
    @upcoming ||= []
  end

  def dump_upcoming
    File.open "#{@config_dir}/upcoming", 'w' do |f|
      @upcoming.each do |flight|
        f.write flight.to_line + "\n"
      end
    end
  end
end