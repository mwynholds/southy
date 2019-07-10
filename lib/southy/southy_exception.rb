module Southy
  class SouthyException < StandardError
    attr_reader :code

    def initialize(message, code = nil)
      super message
      @code = code
    end
  end
end
