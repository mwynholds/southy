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

    run
    delete_pid
  end

  def run
    puts "Southy is running."
    while active? do
      @running = true
      @config.reload

      @config.unconfirmed.each do |flight|
        print "Confirming flight #{flight.confirmation_number}... "
        legs = @agent.confirm(flight)
        puts "confirmed #{legs.length} leg#{legs.length == 1 ? '' : 's'}"
      end

      @config.upcoming.each do |flight|
        flights = @agent.checkin(flight)
        if flights
          flights.each do |f|
            puts "Should email PDF here"
          end
        end
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