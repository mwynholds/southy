class Southy::Service
  def initialize(config, daemon)
    @config = config
    @daemon = daemon
  end

  def run
    @daemon.run
  end

  def start
    pid = get_pid
    if pid
      puts "Southy is already running with PID #{pid}"
      return
    end

    print "Starting Southy... "
    new_pid = Process.fork { @daemon.run }
    Process.detach new_pid
    File.open @config.pid_file, 'w' do |f|
      f.write new_pid.to_s
    end
    puts "started"
  end

  def stop
    pid = get_pid
    unless pid
      puts "Southy is not running"
      return
    end

    print "Stopping Southy..."
    Process.kill 'HUP', pid
    alive = true
    alive_count = 0
    while alive
      alive = `ps -p #{pid} | wc -l`.strip.to_i == 2
      sleep 0.5
      alive_count += 1
      print '.' if alive_count % 10 == 0
      if alive_count >= 120
        puts " failed"
        return
      end
    end
    File.delete @config.pid_file
    puts " stopped"
  end

  def restart
    start
    stop
  end

  def status
    pid = get_pid
    if pid
      puts "Southy is running with PID #{pid}"
    else
      puts "Southy is not running"
    end
  end

  private

  def get_pid
    return nil unless File.exists? @config.pid_file

    IO.read(@config.pid_file).to_i
  end
end