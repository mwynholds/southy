unless defined? String.parse_csv
  require 'csv'

  class String
    def parse_csv
      CSV.parse_line self
    end
  end

  class Array
    def to_csv
      CSV.generate_line(self) + "\n"
    end
  end
end

unless defined? Process.daemon
  module Process
    def self.daemon
      $stdout = File.new('/dev/null', 'w')
    end
  end
end

unless defined? Dir.exists?
  class Dir
    def self.exists?(dir)
      File.directory? dir
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

  class Array
    alias :uniq_without_block :uniq
    def uniq
      if !block_given?
        uniq_without_block
      else
        keys = []
        unique = []
        self.each do |elm|
          key = yield elm
          unless keys.include? key
            unique << elm
            keys << key
          end
        end
        unique
      end
    end
  end
end