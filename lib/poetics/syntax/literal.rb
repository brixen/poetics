module Poetics
  module Syntax
    class Number < Node
      attr_accessor :value

      def initialize(line, column, value)
        super
        @value = value.to_f
      end

      def to_sexp
        [:number, value, line, column]
      end
    end
  end
end
