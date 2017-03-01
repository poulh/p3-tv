# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "p3-tv"
  spec.version       = "0.11.0"
  spec.authors       = ["Poul Hornsleth"]
  spec.email         = ["poulh@umich.edu"]
  spec.summary       = "TV Show Organizer, Renamer, and Downloader"
  spec.description   = "Organize and rename your TV Shows. Automatically find links to missing shows. Includes Command-Line Utility 'p3tv'"
  spec.homepage      = "https://github.com/poulh/p3-tv"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }


  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "p3-eztv", "~> 0.0.7"
  spec.add_runtime_dependency "p3-tvdb", "~> 0.9.0"
  spec.add_runtime_dependency "p3-transmission", "~> 0.0.15"
  spec.add_runtime_dependency "highline", "~> 1.7"

end
