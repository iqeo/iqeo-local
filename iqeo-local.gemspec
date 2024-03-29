# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'iqeo/local'

Gem::Specification.new do |spec|

  spec.name          = "iqeo-local"
  spec.version       = Iqeo::Local::VERSION

  spec.authors       = ["Gerard Fowley"]
  spec.email         = ["gerard.fowley@iqeo.net"]
  spec.summary       = "Local network information"
  spec.description   = "Access local IP configuration: interfaces, addresses, mask, routes, DNS, routes, DHCP, etc.."
  spec.homepage      = ""
  spec.license       = "GPLv3"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-doc"
  spec.add_development_dependency "method_source"

end
