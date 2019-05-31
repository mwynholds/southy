module Southy
  class Passenger < ActiveRecord::Base
    validates  :name, presence: true

    belongs_to :reservation

    def ==(other)
      name == other.name
    end

    def first_name
      name.split(' ').first
    end

    def last_name
      name.split(' ').last
    end
  end
end
