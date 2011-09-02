require 'fileutils'

class Southy::Service
  def initialize(config, daemon)
    @config = config
    @daemon = daemon
  end

  def run
    @daemon.start false
  end

  def start(persist = false)
    pid = get_pid
    if pid
      puts "Southy is already running with PID #{pid}"
      return
    end

    print "Starting Southy... "
    new_pid = Process.fork { @daemon.start }
    Process.detach new_pid
    persist_start if persist
    puts "started"
  end

  def stop(persist = false)
    pid = get_pid
    unless pid
      puts "Southy is not running"
      return
    end

    print "Stopping Southy..."
    persist_stop if persist
    begin
      Process.kill 'HUP', pid
    rescue => e
      @daemon.cleanup
    end
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

  PLIST_SRC = File.join(File.dirname(__FILE__), '../../etc/wynholds.mike.southy.plist')
  PLIST_DEST = "#{ENV['HOME']}/Library/LaunchAgents/wynholds.mike.southy.plist"

  def persist_start
    FileUtils.cp PLIST_SRC, PLIST_DEST
  end

  def persist_stop
    File.delete PLIST_DEST if File.exists? PLIST_DEST
  end
end