require "bundler/gem_tasks"

task :default => :test

desc "Ensure Pester 5.x is installed (>= 5.0, < 6.0)"
task :ensure_pester do
  pester_check = <<~POWERSHELL
    $pester = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge '5.0' -and $_.Version -lt '6.0' } | Select-Object -First 1
    if (-not $pester) {
      Write-Host "Pester 5.x not found. Installing Pester 5.7.1..." -ForegroundColor Yellow
      Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -ErrorAction SilentlyContinue | Out-Null
      Install-Module -Name Pester -RequiredVersion 5.7.1 -Force -SkipPublisherCheck -Scope CurrentUser -Confirm:$false
      Write-Host "Pester 5.7.1 installed successfully." -ForegroundColor Green
    } else {
      Write-Host "Pester $($pester.Version) is already installed." -ForegroundColor Green
    }
  POWERSHELL
  sh "powershell -Command \"#{pester_check.gsub("\n", "; ")}\""
end

desc "Build and install the plugin locally"
task :install_local do
  sh "gem build vagrant-wsl2-provider.gemspec"
  sh "vagrant plugin install vagrant-wsl2-provider-*.gem"
end

desc "Uninstall the plugin"
task :uninstall do
  sh "vagrant plugin uninstall vagrant-wsl2-provider"
end

desc "Run all Pester integration tests"
task :test => :ensure_pester do
  sh "powershell -File test/integration/Invoke-PesterTests.ps1"
end

desc "Run init integration test"
task :test_init => :ensure_pester do
  sh "powershell -File test/integration/Invoke-PesterTests.ps1 -TestFile Init"
end

desc "Run basic integration test"
task :test_basic => :ensure_pester do
  sh "powershell -File test/integration/Invoke-PesterTests.ps1 -TestFile Basic"
end

desc "Run data disk integration test"
task :test_data_disk => :ensure_pester do
  sh "powershell -File test/integration/Invoke-PesterTests.ps1 -TestFile DataDisk"
end

desc "Run snapshot integration test"
task :test_snapshot => :ensure_pester do
  sh "powershell -File test/integration/Invoke-PesterTests.ps1 -TestFile Snapshot"
end

desc "Run networking integration test"
task :test_networking => :ensure_pester do
  sh "powershell -File test/integration/Invoke-PesterTests.ps1 -TestFile Networking"
end

desc "Run multi-VM network integration test"
task :test_multi_vm_network => :ensure_pester do
  sh "powershell -File test/integration/Invoke-PesterTests.ps1 -TestFile MultiVmNetwork"
end

desc "Run provisioners integration test (shell, file, ansible)"
task :test_provisioners => :ensure_pester do
  sh "powershell -File test/integration/Invoke-PesterTests.ps1 -TestFile Provisioners"
end

desc "Run provisioners integration test - full (includes chef and salt)"
task :test_provisioners_full => :ensure_pester do
  sh "powershell -File test/integration/Invoke-PesterTests.ps1 -TestFile Provisioners -Full"
end

desc "Run Docker integration test (3 distros)"
task :test_docker => :ensure_pester do
  sh "powershell -File test/integration/Invoke-PesterTests.ps1 -TestFile Docker"
end

desc "Run Docker integration test - full (all distros)"
task :test_docker_full => :ensure_pester do
  sh "powershell -File test/integration/Invoke-PesterTests.ps1 -TestFile Docker -Full"
end

desc "Run all distributions compatibility test - quick (Pester, 3 distros)"
task :test_all_distributions => :ensure_pester do
  sh "powershell -File test/integration/Invoke-PesterTests.ps1 -TestFile AllDistributions"
end

desc "Run all distributions compatibility test - full (Pester, all distros)"
task :test_all_distributions_full => :ensure_pester do
  sh "powershell -File test/integration/Invoke-PesterTests.ps1 -TestFile AllDistributions -Full"
end