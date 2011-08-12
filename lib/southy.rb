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
      puts "Looking up itineraries..."
      visit('/flight/retrieveCheckinDoc.html?forceNewSession=yes')

      within '#itineraryLookup' do
        fill_in 'confirmationNumber', :with => 'W8F25E'.ljust(12)
        fill_in 'First Name', :with => 'Michael'.ljust(30)
        fill_in 'Last Name', :with => 'Wynholds'.ljust(30)
        find('#submitButton').click
      end

      if find('#checkinOptions') == nil
        puts "Can't find and flights.  Sorry."
        return
      end

      within '#checkinOptions' do
        all('input[type="checkbox"]').each {|i| check i[:id] }
        puts "Checking in..."
        find('#printDocumentsButton').click
      end

      all('.checkinDocument').each do |node|
        doc = CheckinDocument.parse node
        puts "Checked in: #{doc.first_name} #{doc.last_name} - #{doc.group}#{doc.position}"
      end

    end
  end
end
