# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "tvtime"
  spec.version       = "0.0.1"
  spec.authors       = ["Poul Hornsleth"]
  spec.email         = ["poulh@umich.edu"]
  spec.summary       = "TV Show Organizer"
  spec.description   = "Swiss army knife utility for everything related to your TV shows"
  spec.homepage      = "https://github.com/poulh/tvtime"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  # spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  # spec.add_development_dependency "bundler", "~> 1.5"
  # spec.add_development_dependency "rake"
  # spec.add_development_dependency "minitest"

  spec.add_runtime_dependency "eztv", "~> 0.0.5"

end
