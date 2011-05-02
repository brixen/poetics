module Poetics
  class CodeLoader
    def self.evaluate(string)
      # We're just parsing for now
      Poetics::Parser.parse_to_sexp string
    end

    def self.execute_file(name)
      value = Poetics::Parser.parse_to_sexp IO.read(name)
      p value
    end
  end
end
