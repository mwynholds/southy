class Southy::Timezones
  LOOKUP =
  {
    'DEN' => 'America/Denver',
    'HOU' => 'America/Chicago',
    'LAX' => 'America/Los_Angeles',
    'MSY' => 'America/Chicago',
    'SFO' => 'America/Los_Angeles'
  }

  def self.lookup(code)
    LOOKUP[code]
  end
end
