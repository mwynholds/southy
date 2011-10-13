class Southy::Daemon

  def initialize(travel_agent)
    @agent = travel_agent
    @config = travel_agent.config
    @active = true
    @running = false
  end

  def start(daemonize = true)
    Process.daemon if daemonize
    write_pid

    [ 'HUP', 'INT', 'QUIT', 'TERM' ].each do |sig|
      Signal.trap(sig) { kill }
    end

    begin
      run
    ensure
      delete_pid
    end
  end

  def run
    puts "Southy is running."
    while active? do
      @running = true
      @config.reload

      @config.unconfirmed.each do |flight|
        @agent.confirm(flight)
      end

      @config.upcoming.each do |flight|
        @agent.checkin(flight)
      end

      sleep 0.5
    end
  end

  def cleanup
    delete_pid
  end

  private

  def active?
    @active
  end

  def kill
    @active = false
  end

  def write_pid
    File.open @config.pid_file, 'w' do |f|
      f.write Process.pid.to_s
    end
  end

  def delete_pid
    File.delete @config.pid_file if File.exists? @config.pid_file
  end
end