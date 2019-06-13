module Southy
  class Seat < ActiveRecord::Base
    validates  :group, presence: true
    validates  :position, presence: true
    validates  :flight, presence: true

    belongs_to :bound
    belongs_to :passenger

    def ident
      "#{group}#{position}"
    end
  end
end
