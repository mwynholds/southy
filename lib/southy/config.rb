require 'tmpdir'

class Southy::Config
  def initialize(config_dir = nil)
    @config_dir = config_dir || Dir.mktmpdir
    FileUtils.mkdir @config_dir unless Dir.exists? @config_dir
  end

  def add(conf, first_name = nil, last_name = nil)
    File.open "#{@config_dir}/upcoming", 'a' do |f|
      f.write "#{conf},#{first_name},#{last_name}\n"
    end
  end

  def remove(conf)
    puts "remove #{conf}"
  end
end