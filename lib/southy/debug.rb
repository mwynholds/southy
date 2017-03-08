require 'date'

class Debug
  def self.debug=(debug)
    ENV['DEBUG'] = debug.to_s
  end

  def self.is_debug?
    ENV['DEBUG'] == 'true'
  end

  def self.periodically(seconds)
    now = DateTime.now
    if now.second % seconds == 0
      yield
    end
  end
end
