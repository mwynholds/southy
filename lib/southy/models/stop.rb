module Southy
  class Stop < ActiveRecord::Base
    validates  :code, presence: true
    validates  :arrival_time, presence: true
    validates  :departure_time, presence: true

    belongs_to :bound

    def airport
      Airport.lookup code
    end
  end
end
