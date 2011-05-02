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

    class Boolean < Node
      def to_sexp
        [sexp_name, line, column]
      end
    end

    class True < Boolean
      def sexp_name
        :true
      end
    end

    class False < Boolean
      def sexp_name
        :false
      end
    end

    class Null < Boolean
      def sexp_name
        :null
      end
    end

    class Undefined < Boolean
      def sexp_name
        :undefined
      end
    end
  end
end
