require 'capybara/dsl'
require 'capybara-webkit'
require 'fileutils'

class Southy::Monkey
  Capybara.default_driver = :webkit
  Capybara.app_host = 'http://www.southwest.com'
  include Capybara::DSL

  def lookup(conf, first_name, last_name)
    visit 'https://www.southwest.com/flight/lookup-air-reservation.html'

    fill_in 'confirmationNumber', :with => conf.ljust(6)
    fill_in 'confirmationNumberFirstName', :with => first_name.ljust(30)
    fill_in 'confirmationNumberLastName', :with => last_name.ljust(30)
    find('#pnrFriendlyLookup_check_form_submitButton').click

    flights = []
    all('.itinerary_container').each do |container|
      if container
        container.all('.airProductItineraryTable').each do |node|
          flights << Southy::Flight.from_dom(container, node)
        end
      end
    end

    flights
  end

  def checkin(flight)
    visit '/flight/retrieveCheckinDoc.html?forceNewSession=yes'

    within '#itineraryLookup' do
      fill_in 'confirmationNumber', :with => flight.confirmation_number.ljust(12)
      fill_in 'First Name', :with => flight.first_name.ljust(30)
      fill_in 'Last Name', :with => flight.last_name.ljust(30)
      find('#submitButton').click
    end

    if ! has_css?('#checkinOptions')
      return nil
    end

    within '#checkinOptions' do
      all('input[type="checkbox"]').each {|i| check i[:id] }
      find('#printDocumentsButton').click
    end

    docs = []
    all('.checkinDocument').each do |node|
      doc = Southy::CheckingDocument.parse(node)
      doc.flight = flight
      docs << doc
    end

    docs
  end
end