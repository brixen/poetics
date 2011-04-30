module Poetics
  module Syntax
    def number(value)
      Number.new line, column, value
    end
  end
end
