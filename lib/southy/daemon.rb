class Southy::Daemon

  def initialize(config, monkey)
    @config = config
    @monkey = monkey
    @active = true
    @running = false
  end

  def start
    Process.daemon
    write_pid

    Signal.trap 'HUP' do
      kill
    end

    run
  end

  def run
    puts "Southy is running."
    while active? do
      @running = true
      @config.reload
      @config.upcoming.each do |flight|
        if flight.checkin_available?
          docs = @monkey.checkin flight
          if docs
            docs.each do |doc|
              puts "Should email PDF here"
            end
          end
        elsif !flight.confirmed?
          print "Confirming flight #{flight.confirmation_number}... "
          legs = @monkey.lookup flight.confirmation_number, flight.first_name, flight.last_name
          legs.each do |f|
            @config.confirm f
          end
          puts "confirmed #{legs.length} leg#{legs.length == 1 ? '' : 's'}"
        end
      end
      sleep 2
    end
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
end