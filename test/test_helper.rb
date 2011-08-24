ENV['RACK_ENV'] = 'test'

$LOAD_PATH << File.dirname(__FILE__) + "/../lib"
require 'southy'

require 'minitest/autorun'