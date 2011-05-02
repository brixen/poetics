module Poetics
  module Syntax
    def number(value)
      Number.new line, column, value
    end

    def hexadecimal(value)
      Number.new line, column, value.to_i(16)
    end

    def true_value
      True.new line, column
    end

    def false_value
      False.new line, column
    end

    def null_value
      Null.new line, column
    end

    def undefined_value
      Undefined.new line, column
    end
  end
end
