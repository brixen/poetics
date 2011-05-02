module Poetics
  module Syntax
    class Value < Node
      def to_sexp
        [sexp_name, value, line, column]
      end
    end

    class Number < Value
      attr_accessor :value

      def initialize(line, column, value)
        super
        @value = value.to_f
      end

      def sexp_name
        :number
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

    class String < Value
      attr_accessor :value

      def initialize(line, column, text)
        super
        @value = text
      end

      def sexp_name
        :string
      end
    end
  end
end
