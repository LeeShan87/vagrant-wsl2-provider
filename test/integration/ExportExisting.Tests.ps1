# Export Existing Distribution integration test for Vagrant WSL2 Provider
# Tests: Exporting existing local distributions that support --name flag to cache
# Pester 5.x format

BeforeAll {
    $script:ExampleDir = Join-Path $PSScriptRoot "..\..\examples\export-existing"
    $script:TestDistro = "Ubuntu-24.04"  # Must support --name flag
    $script:ProjectDistroName = "vagrant-wsl2-export-test"

    # Ensure we're in the correct directory
    Push-Location $script:ExampleDir

    # Cleanup any existing instances
    vagrant destroy -f 2>$null | Out-Null

    # Cleanup cache if it exists
    $cacheDir = Join-Path $env:USERPROFILE ".vagrant.d\wsl2-cache"
    $cacheTar = Join-Path $cacheDir "$script:TestDistro-vagrant-base.tar"
    if (Test-Path $cacheTar) {
        Remove-Item $cacheTar -Force
        Write-Host "Removed existing cache: $cacheTar"
    }

    # Ensure test distribution is installed locally
    # Check if already installed
    $installedDistros = wsl --list --quiet 2>&1
    $distroInstalled = $false

    if ($LASTEXITCODE -eq 0) {
        $installedDistros = $installedDistros -replace '\x00', ''
        foreach ($line in $installedDistros -split "`r?`n") {
            if ($line.Trim() -eq $script:TestDistro) {
                $distroInstalled = $true
                break
            }
        }
    }

    if (-not $distroInstalled) {
        Write-Host "Installing test distribution: $script:TestDistro"
        wsl --install --distribution $script:TestDistro --no-launch
        Start-Sleep -Seconds 10  # Wait for installation
    }
}

AfterAll {
    # Cleanup after all tests
    vagrant destroy -f 2>$null | Out-Null
    Pop-Location
}

Describe "Vagrant WSL2 Provider - Export Existing Distribution" {

    Context "When exporting an existing distribution to cache" {

        It "Should detect that test distribution is installed locally" {
            $installedDistros = wsl --list --quiet 2>&1
            $installedDistros = $installedDistros -replace '\x00', ''
            $distroFound = $false

            foreach ($line in $installedDistros -split "`r?`n") {
                if ($line.Trim() -eq $script:TestDistro) {
                    $distroFound = $true
                    break
                }
            }

            $distroFound | Should -Be $true
        }

        It "Should successfully run vagrant up and export to cache" {
            vagrant up
            $LASTEXITCODE | Should -Be 0
        }

        It "Should have created the cache tar file" {
            $cacheDir = Join-Path $env:USERPROFILE ".vagrant.d\wsl2-cache"
            $cacheTar = Join-Path $cacheDir "$script:TestDistro-vagrant-base.tar"
            Test-Path $cacheTar | Should -Be $true
        }

        It "Should have created the project distribution" {
            $installedDistros = wsl --list --quiet 2>&1
            $installedDistros = $installedDistros -replace '\x00', ''
            $projectFound = $false

            foreach ($line in $installedDistros -split "`r?`n") {
                if ($line.Trim() -eq $script:TestDistro) {
                    $projectFound = $true
                    break
                }
            }

            $projectFound | Should -Be $true
        }

        It "Should report running state" {
            $output = (vagrant status) -join "`n"
            $output | Should -Match "running"
        }

        It "Should be able to SSH into the VM" {
            $result = vagrant ssh -c "echo 'test'"
            $LASTEXITCODE | Should -Be 0
            $result | Should -Match "test"
        }

        It "Should have vagrant user configured" {
            $result = vagrant ssh -c "whoami"
            $LASTEXITCODE | Should -Be 0
            $result | Should -Match "vagrant"
        }
    }

    Context "When creating a second VM from cache" {

        It "Should successfully destroy the first VM" {
            vagrant destroy -f
            $LASTEXITCODE | Should -Be 0
        }

        It "Should create second VM from cache (faster - no export)" {
            # Measure time - should be faster since cache exists
            $startTime = Get-Date
            vagrant up
            $duration = (Get-Date) - $startTime

            $LASTEXITCODE | Should -Be 0
            # Should be faster than 30 seconds since no export needed
            $duration.TotalSeconds | Should -BeLessThan 60
        }

        It "Should have the second VM running" {
            $output = (vagrant status) -join "`n"
            $output | Should -Match "running"
        }
    }

    Context "When cleaning up" {

        It "Should successfully destroy the VM" {
            vagrant destroy -f
            $LASTEXITCODE | Should -Be 0
        }

        It "Should report not created state" {
            $output = (vagrant status) -join "`n"
            $output | Should -Match "not created"
        }

        It "Should have removed the project distribution but kept the original" {
            $installedDistros = wsl --list --quiet 2>&1
            if ($LASTEXITCODE -eq 0) {
                $installedDistros = $installedDistros -replace '\x00', ''
                $originalFound = $false
                $projectFound = $false

                foreach ($line in $installedDistros -split "`r?`n") {
                    $distroName = $line.Trim()
                    if ($distroName -eq $script:TestDistro) {
                        $originalFound = $true
                    }
                    # Check for project distribution (box name with timestamp collision suffix)
                    if ($distroName -match "^$script:TestDistro_\d+$") {
                        $projectFound = $true
                    }
                }

                # Original distribution should still exist
                $originalFound | Should -Be $true
                # Project distribution should be removed
                $projectFound | Should -Be $false
            }
        }

        It "Should keep the cache tar file for future use" {
            $cacheDir = Join-Path $env:USERPROFILE ".vagrant.d\wsl2-cache"
            $cacheTar = Join-Path $cacheDir "$script:TestDistro-vagrant-base.tar"
            Test-Path $cacheTar | Should -Be $true
        }
    }
}
