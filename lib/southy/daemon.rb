class Southy::Daemon

  def initialize(config, monkey)
    @config = config
    @monkey = monkey
    @active = true
    @running = false
  end

  def run
    while active? do
      @running = true
      @config.reload
      @config.upcoming.each do |flight|
        if flight.checkin_available?
          puts "Should be checking in here"
        elsif !flight.confirmed?
          print "Confirming flight #{flight.confirmation_number}... "
          confirmed = @monkey.lookup flight.confirmation_number, flight.first_name, flight.last_name
          confirmed.each do |f|
            @config.confirm f
          end
          puts "#{confirmed.length} successful"
        else
          puts "Waiting for something to do..."
        end
      end
      sleep 2
    end
  end

  def active?
    @active
  end

  def kill
    @active = false
    while @running
      sleep 0.25
    end
  end
end