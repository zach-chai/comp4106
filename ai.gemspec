# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ai/version'

Gem::Specification.new do |spec|
  spec.name          = "ai"
  spec.version       = Ai::VERSION
  spec.authors       = ["Zachary Chai"]
  spec.email         = ["zachary.chai@outlook.com"]

  spec.summary       = %q{AI}
  spec.description   = %q{AI}
  spec.homepage      = ""
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.executables   = "ai"
  spec.require_paths = ["lib"]

   spec.add_dependency "slop"
   spec.add_dependency "pqueue"
   spec.add_dependency "ruby_deep_clone"
   spec.add_dependency "ruby-graphviz"
   spec.add_dependency "terminal-table"

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 12.0"
end
