module Poetics
  module Syntax
    class Node
      attr_accessor :line, :column

      def initialize(line, column, *)
        @line = line
        @column = column
      end

      def to_sexp
      end
    end
  end
end
