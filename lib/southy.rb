module Southy
  begin
    require 'pry'
  rescue LoadError
  end

  require 'southy/version'
  require 'southy/helpers'
  require 'southy/monkey'
  require 'southy/service'
  require 'southy/config'
  require 'southy/daemon'
  require 'southy/flight'
  require 'southy/travel_agent'
  require 'southy/airport'
  require 'southy/cli'
  require 'southy/bot'

  require 'ext/xmpp4r-simple'
  require 'ext/jabber-bot'
end
