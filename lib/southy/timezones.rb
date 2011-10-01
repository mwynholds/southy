class Southy::Timezones
  LOOKUP =
  {
    'HOU' => 'America/Chicago',
    'LAX' => 'America/Los_Angeles',
    'MSY' => 'America/Chicago'
  }

  def self.lookup(code)
    LOOKUP[code]
  end
end
