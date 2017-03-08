class Debug
  @@last = ::DateTime.new(2000, 1, 1)

  def self.debug=(debug)
    ENV['DEBUG'] = debug.to_s
  end

  def self.is_debug?
    ENV['DEBUG'] == 'true'
  end

  def self.periodically(seconds)
    now = DateTime.now
    if now.second % seconds == 0 && ( now.to_i - @@last.to_i > seconds/2 )
      yield
      @@last = now
    end
  end
end
