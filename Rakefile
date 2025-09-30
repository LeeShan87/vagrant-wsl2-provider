require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

desc "Build and install the plugin locally"
task :install_local do
  sh "gem build vagrant-wsl2-provider.gemspec"
  sh "vagrant plugin install vagrant-wsl2-provider-*.gem"
end

desc "Uninstall the plugin"
task :uninstall do
  sh "vagrant plugin uninstall vagrant-wsl2-provider"
end