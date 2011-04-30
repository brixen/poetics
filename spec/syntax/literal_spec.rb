require 'spec/spec_helper'

describe "The Number node" do
  relates "42" do
    parse do
      [:number, 42.0, 1, 1]
    end
  end
end
