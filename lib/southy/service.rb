require 'fileutils'

class Southy::Service
  def initialize(travel_agent, daemon)
    @agent = travel_agent
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

    if persist
      persist_stop
    else
      begin
        Process.kill 'HUP', pid
      rescue
        @daemon.cleanup
      end
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
      puts "Southy is running with PID #{pid} in env #{ENV['RUBY_ENV']}"
      true
    else
      puts "Southy is not running"
      false
    end
  end

  private

  def get_pid
    return nil unless File.exists? @agent.config.pid_file
    IO.read(@agent.config.pid_file).to_i
  end

  PLIST_SRC = File.join(File.dirname(__FILE__), '../../etc/wynholds.mike.southy.plist')
  PLIST_DEST = "#{ENV['HOME']}/Library/LaunchAgents/wynholds.mike.southy.plist"

  def persist_start
    FileUtils.cp PLIST_SRC, PLIST_DEST
    system "launchctl load -w #{PLIST_DEST}"
  end

  def persist_stop
    system "launchctl unload -w #{File.basename PLIST_DEST}"
    File.delete PLIST_DEST if File.exists? PLIST_DEST
  end

end
