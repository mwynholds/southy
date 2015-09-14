require 'bundler/gem_tasks'

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

require 'southy'
task :test_lookup do
  config = Southy::Config.new
  monkey = Southy::Monkey.new config
  monkey.lookup '8T4YEJ', 'Matthew', 'Sullivan'
end

task :default => :test
