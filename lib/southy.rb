require 'capybara/dsl'
require 'capybara-webkit'

module Southy
  VERSION = "0.0.1"

  require 'southy/checkin_document'

  class CLI
    Capybara.default_driver = :webkit
    Capybara.app_host = 'http://www.southwest.com'
    #Capybara.app_host = 'http://localhost:9000'
    include Capybara::DSL
    
    def start(params)
      puts "Starting..."
    end

    def stop(params)
      puts "Stopping..."
    end

    def test(params)
      puts "Testing..."
      visit('/flight/retrieveCheckinDoc.html?forceNewSession=yes')
      puts "Made it to southwest.com..."

      within '#itineraryLookup' do
        fill_in 'confirmationNumber', :with => 'W8F25E'.ljust(12)
        fill_in 'First Name', :with => 'Michael'.ljust(30)
        fill_in 'Last Name', :with => 'Wynholds'.ljust(30)
        puts "Looking up the itineraries..."
        find('#submitButton').click
      end

      within '#checkinOptions' do
        all('input[type="checkbox"]').each {|i| check i[:id] }
        puts "Checking in..."
        find('#printDocumentsButton').click
      end

      all('.checkinDocument').each do |node|
        checkin_doc = CheckinDocument.parse node
        p checkin_doc
      end

    end
  end
end
