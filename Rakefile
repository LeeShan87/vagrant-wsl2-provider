require "bundler/gem_tasks"

task :default => :test

desc "Build and install the plugin locally"
task :install_local do
  sh "gem build vagrant-wsl2-provider.gemspec"
  sh "vagrant plugin install vagrant-wsl2-provider-*.gem"
end

desc "Uninstall the plugin"
task :uninstall do
  sh "vagrant plugin uninstall vagrant-wsl2-provider"
end

desc "Run all integration tests"
task :test do
  sh "powershell -File test/integration/run_all_tests.ps1"
end

desc "Run basic integration test"
task :test_basic do
  sh "powershell -File test/integration/test_basic.ps1"
end

desc "Run snapshot integration test"
task :test_snapshot do
  sh "powershell -File test/integration/test_snapshot.ps1"
end