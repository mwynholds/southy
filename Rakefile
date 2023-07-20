require 'bundler/gem_tasks'

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

require 'standalone_migrations'
ENV["SCHEMA"] = File.join(ActiveRecord::Tasks::DatabaseTasks.db_dir, "schema.rb")
StandaloneMigrations::Tasks.load_tasks

task :default => :test
