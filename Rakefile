require 'bundler/gem_tasks'

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

require 'southy'
task 'test:lookup' do
  config = Southy::Config.new
  monkey = Southy::TestMonkey.new config
  flights = monkey.lookup '5JFALO', 'Hans', 'Wynholds'
  pp flights
end

task :default => :test
