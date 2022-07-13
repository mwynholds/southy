# -*- encoding: utf-8 -*-
$LOAD_PATH << File.dirname(__FILE__) + "/lib"
require 'southy/version'

Gem::Specification.new do |s|
  s.name        = "southy"
  s.version     = Southy::VERSION
  s.authors     = ["Michael Wynholds"]
  s.email       = ["mike@carbonfive.com"]
  s.homepage    = ""
  s.summary     = %q{Auto check-ins for Southwest flights}
  s.description = %q{Auto check-ins for Southwest flights}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }.reject{ |n| n == 'deploy' }
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'json'
  s.add_runtime_dependency 'tzinfo'
  s.add_runtime_dependency 'slack-ruby-client', ">= 0.17.0"
  s.add_runtime_dependency 'async-websocket', "= 0.8.0"  # slack-ruby-client breaks with anything greater
  s.add_runtime_dependency 'activerecord', ">= 5.2.4.1", "< 7.0.4.0"      # 6.0 not supported by standalone_migrations gemspec
  s.add_runtime_dependency 'standalone_migrations'
  s.add_runtime_dependency 'pg'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'minitest'
end
