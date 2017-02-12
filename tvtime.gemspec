# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "tvtime"
  spec.version       = "0.1.1"
  spec.authors       = ["Poul Hornsleth"]
  spec.email         = ["poulh@umich.edu"]
  spec.summary       = "TV Show Organizer and Renamer"
  spec.description   = "Organize and rename your TV Shows. Automatically find links to missing shows.  See homepage for instructions on installing eztv gem"
  spec.homepage      = "https://github.com/poulh/tvtime"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }

  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "eztv", "~> 0.0.5"
  spec.add_runtime_dependency "imdb", "~> 0.8.2"
  spec.add_runtime_dependency "tvdb_party", "~> 0.8.1"

end
