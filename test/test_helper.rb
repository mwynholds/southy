ENV['RACK_ENV'] = 'test'

$LOAD_PATH << File.dirname(__FILE__) + "/../lib"
require 'southy'

require 'minitest/autorun'

require 'factory_girl'
FactoryGirl.definition_file_paths = [ File.dirname(__FILE__) + '/factories' ]
FactoryGirl.find_definitions