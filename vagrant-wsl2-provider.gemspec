lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "vagrant-wsl2-provider/version"

Gem::Specification.new do |spec|
  spec.name          = "vagrant-wsl2-provider"
  spec.version       = VagrantPlugins::WSL2::VERSION
  spec.authors       = ["Zoltan Toma"]
  spec.email         = ["zoltantoma87@gmail.com"]

  spec.summary       = "Vagrant WSL2 provider plugin"
  spec.description   = "A Vagrant provider plugin for managing WSL2 distributions"
  spec.homepage      = "https://github.com/LeeShan87/vagrant-wsl2-provider"
  spec.license       = "MIT"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir["lib/**/*", "locales/**/*", "*.md", "*.txt", "LICENSE", "Rakefile", "Gemfile", "*.gemspec"]
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end