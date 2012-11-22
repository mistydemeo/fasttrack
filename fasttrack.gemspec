# -*- encoding: utf-8 -*-
require File.expand_path('../lib/fasttrack/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Misty De Meo"]
  gem.email         = ["mistydemeo@gmail.com"]
  gem.description   = <<-EOS
                      Fasttrack is an easy-to-use Ruby wrapper for
                      Exempi, a C library for managing XMP metadata.
                      Fasttrack provides a dead-easy, object-oriented
                      interface to Exempi's functions.
                      EOS
  gem.summary       = %q{Ruby sugar for Exempi}
  gem.homepage      = "https://github.com/mistydemeo/fasttrack"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "fasttrack"
  gem.require_paths = ["lib"]
  gem.version       = Fasttrack::VERSION

  gem.add_dependency 'exempi', '>= 0.1'

  gem.add_development_dependency 'rake', '>= 0.9.2.2'
  gem.add_development_dependency 'mocha', '>= 0.13.0'
  gem.add_development_dependency 'nokogiri', '>= 1.5.5'
end
