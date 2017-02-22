# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "tvtime"
  spec.version       = "0.7.5"
  spec.authors       = ["Poul Hornsleth"]
  spec.email         = ["poulh@umich.edu"]
  spec.summary       = "TV Show Organizer and Renamer"
  spec.description   = "Organize and rename your TV Shows. Automatically find links to missing shows. Includes Command-Line Utility"
  spec.homepage      = "https://github.com/poulh/tvtime"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }


  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "tvez", "~> 0.0.6"
  spec.add_runtime_dependency "tvdb_party", "~> 0.8.2"
  spec.add_runtime_dependency "transmission_api", "~> 0.0.14"
  spec.add_runtime_dependency "highline", "~> 1.7"

end
