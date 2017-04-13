module PoAndXliffConsolidator
  module Analyse

    def self.quality(string)
      return 0 if string == string.downcase
      return 0 if string == string.upcase
      return 1
    end

  end
end
