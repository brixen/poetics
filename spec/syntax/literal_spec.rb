require 'spec/spec_helper'

describe "The Number node" do
  relates "42" do
    parse { [:number, 42.0, 1, 1] }
  end

  relates " 42" do
    parse { [:number, 42.0, 1, 2] }
  end

  relates "42 " do
    parse { [:number, 42.0, 1, 1] }
  end

  relates "1.23" do
    parse { [:number, 1.23, 1, 1] }
  end

  relates "0x2a" do
    parse { [:number, 42.0, 1, 1] }
  end
end

describe "The True node" do
  relates "true" do
    parse { [:true, 1, 1] }
  end
end

describe "The False node" do
  relates "false" do
    parse { [:false, 1, 1] }
  end
end

describe "The Null node" do
  relates "null" do
    parse { [:null, 1, 1] }
  end
end

describe "The Undefined node" do
  relates "undefined" do
    parse { [:undefined, 1, 1] }
  end
end

describe "The String node" do
  relates '"hello, world"' do
    parse { [:string, "hello, world", 1, 1] }
  end

  relates <<-ruby do
      "hello"
    ruby

    parse { [:string, "hello", 1, 7] }
  end
end
