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
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'nokogiri'
  s.add_runtime_dependency 'json'
  s.add_runtime_dependency 'tzinfo'
  s.add_runtime_dependency 'pdfkit'
  s.add_runtime_dependency 'xmpp4r'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'launchy'
  s.add_development_dependency 'factory_girl'
  s.add_development_dependency 'timecop'
  s.add_development_dependency 'pry-debugger'
end
