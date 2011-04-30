# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "poetics/version"

Gem::Specification.new do |s|
  s.name        = "poetics"
  s.version     = Poetics::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Brian Ford"]
  s.email       = ["brixen@gmail.com"]
  s.homepage    = "https://github.com/brixen/poetics"
  s.summary     = %q{A native implementation of CoffeeScript on the Rubinius VM}
  s.description =<<-EOD
Poetics implements CoffeeScript (http://jashkenas.github.com/coffee-script/)
directly on the Rubinius VM (http://rubini.us). It includes a REPL for
exploratory programming, as well as executing CoffeeScript scripts directly.
  EOD

  s.files         = `git ls-files`.split("\n")
  s.test_files    = Dir["spec/**/*.rb"]
  s.executables   = ["poetics"]
  s.require_paths = ["lib"]
end
