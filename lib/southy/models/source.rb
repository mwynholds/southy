module Southy
  class Source < ActiveRecord::Base
    validates :json, presence: true
  end
end
