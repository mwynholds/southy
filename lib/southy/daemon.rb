class Southy::Daemon

  def initialize(travel_agent)
    @agent = travel_agent
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
      @agent.config.reload
      @agent.config.upcoming.each do |flight|
        if flight.checkin_available?
          docs = @agent.monkey.checkin flight
          if docs
            docs.each do |doc|
              puts "Should email PDF here"
            end
          end
        elsif !flight.confirmed?
          print "Confirming flight #{flight.confirmation_number}... "
          legs = @agent.monkey.lookup flight.confirmation_number, flight.first_name, flight.last_name
          legs.each do |f|
            f.email = flight.email
            @agent.config.confirm f
          end
          puts "confirmed #{legs.length} leg#{legs.length == 1 ? '' : 's'}"
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
    File.open @agent.config.pid_file, 'w' do |f|
      f.write Process.pid.to_s
    end
  end

  def delete_pid
    File.delete @agent.config.pid_file if File.exists? @agent.config.pid_file
  end
end