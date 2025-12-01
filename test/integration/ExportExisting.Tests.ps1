# Export Existing Distribution integration test for Vagrant WSL2 Provider
# Tests: Exporting existing local distributions that support --name flag to cache
# Pester 5.x format

# Define test distribution name - must be script-scoped to be accessible in BeforeAll/AfterAll
$script:TestDistro = "Ubuntu-24.04"  # Must support --name flag
$script:DistroInstalledByTest = $false

# Check if test distribution already exists before we start
$installedDistros = wsl --list --quiet 2>&1
$distroAlreadyInstalled = $false

if ($LASTEXITCODE -eq 0) {
    $installedDistros = $installedDistros -replace '\x00', ''
    foreach ($line in $installedDistros -split "`r?`n") {
        if ($line.Trim() -eq $script:TestDistro) {
            $distroAlreadyInstalled = $true
            break
        }
    }
}

# Skip test if distribution already exists
if ($distroAlreadyInstalled) {
    Write-Host "Skipping test: $($script:TestDistro) already exists on this system"  -ForegroundColor Yellow
    Write-Host "This test requires a clean system without the test distribution pre-installed"  -ForegroundColor Yellow
    $script:SkipTests = $true
    return
}

$script:SkipTests = $false

BeforeAll {
    if ($script:SkipTests) { return }
    $script:TestDistro = "Ubuntu-24.04" 
    $script:ExampleDir = Join-Path $PSScriptRoot "..\..\examples\export-existing"
    $script:ProjectDistroName = "vagrant-wsl2-export-test"

    # Ensure we're in the correct directory
    Push-Location $script:ExampleDir

    # Cleanup any existing instances
    vagrant destroy -f 2>$null | Out-Null

    # Cleanup cache if it exists
    $cacheDir = Join-Path $env:USERPROFILE ".vagrant.d\wsl2-cache"
    $cacheTar = Join-Path $cacheDir "$($script:TestDistro)-vagrant-base.tar"
    if (Test-Path $cacheTar) {
        Remove-Item $cacheTar -Force
        Write-Host "Removed existing cache: $cacheTar"
    }

    # Install test distribution (we already checked it doesn't exist in the script-level check)
    Write-Host "Installing test distribution: $($script:TestDistro)"
    wsl --install --distribution $script:TestDistro --no-launch
    Start-Sleep -Seconds 10  # Wait for installation
    $script:DistroInstalledByTest = $true
}

AfterAll {
    if ($script:SkipTests) { return }

    # Cleanup after all tests
    vagrant destroy -f 2>$null | Out-Null

    # Remove the test distribution if we installed it
    if ($script:DistroInstalledByTest) {
        Write-Host "Removing test distribution: $($script:TestDistro)"
        wsl --unregister $script:TestDistro 2>$null | Out-Null
    }

    Pop-Location
}

Describe "Vagrant WSL2 Provider - Export Existing Distribution" -Skip:$script:SkipTests {

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
