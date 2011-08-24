require 'tmpdir'
require 'yaml'

class Southy::Config
  def initialize(config_dir = nil)
    @config_dir = config_dir || Dir.mktmpdir
    FileUtils.mkdir @config_dir unless Dir.exists? @config_dir

    load_config
  end

  def init(first_name, last_name)
    File.open "#{@config_dir}/config", "w" do |f|
      f.write({:first_name => first_name, :last_name => last_name}.to_yaml)
    end

    load_config
  end

  def add(conf, first_name = nil, last_name = nil)
    first_name ||= @config[:first_name]
    last_name ||= @config[:last_name]

    File.open "#{@config_dir}/upcoming", 'a' do |f|
      f.write "#{conf},#{first_name},#{last_name}\n"
    end
  end

  def remove(conf)
    puts "remove #{conf}"
  end

  private

  def load_config
    config_file = "#{@config_dir}/config"
    @config = YAML.load( IO.read(config_file) ) if File.exists? config_file
  end
end