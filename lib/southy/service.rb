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
    new_pid = Process.fork { @daemon.start }
    Process.detach new_pid
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
    ticks = 0
    while pid = get_pid && ticks < 40
      sleep 0.5
      ticks += 1
      print '.' if ticks % 4 == 0
    end
    puts " #{pid.nil? ? 'stopped' : 'failed'}"
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