module Southy
  begin
    require 'pry'
  rescue LoadError
  end

  require 'active_record'

  require 'southy/version'
  require 'southy/helpers'
  require 'southy/debug'
  require 'southy/southy_exception'
  require 'southy/models/airport'
  require 'southy/models/seat'
  require 'southy/models/stop'
  require 'southy/models/passenger'
  require 'southy/models/bound'
  require 'southy/models/reservation'
  require 'southy/models/message'
  require 'southy/models/leg'
  require 'southy/mailer'
  require 'southy/monkey'
  require 'southy/service'
  require 'southy/config'
  require 'southy/travel_agent'
  require 'southy/cli'
  require 'southy/slackbot'

  env    = ENV['RUBY_ENV'] || 'development'
  config = YAML.load File.read "#{__dir__}/../db/config.yml"
  ActiveRecord::Base.establish_connection config[env]
end
