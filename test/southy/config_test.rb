require 'test_helper'
require 'fileutils'

class ConfigTest < MiniTest::Spec
  
  describe 'Config' do

    before do
      @config_dir = "#{File.dirname(__FILE__)}/../../.config_test_#{rand 1000}"
      FileUtils.remove_entry_secure @config_dir if Dir.exists? @config_dir
    end

    describe '#add' do
      describe 'with name' do
        before do
          config = Southy::Config.new @config_dir
          config.add 'ABCDEF', 'First', 'Last'
          config.add 'GHIJKL', 'One', 'Two'
          @contents = IO.read "#{@config_dir}/upcoming"
        end

        it 'adds the flight' do
          @contents.must_equal <<EOF
ABCDEF,First,Last
GHIJKL,One,Two
EOF
        end
      end

      describe 'without name' do

      end
    end

    after do
      FileUtils.remove_entry_secure @config_dir if Dir.exists? @config_dir
    end

  end
end