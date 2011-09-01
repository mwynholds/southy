unless defined? String.parse_csv
  require 'csv'

  class String
    def parse_csv
      CSV.parse_line self
    end
  end

  class Array
    def to_csv
      CSV.generate_line self
    end
  end
end

unless defined? Process.daemon
  module Process
    def self.daemon
      # noop?
    end
  end
end

if RUBY_VERSION =~ /^1\.8/
  module Kernel
    alias :print_without_flush :print
    def print(obj, *smth)
      print_without_flush obj, smth
      STDOUT.flush
    end
  end
end