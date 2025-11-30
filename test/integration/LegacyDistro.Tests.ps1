# Legacy Distribution integration test for Vagrant WSL2 Provider
# Tests: Installing and caching legacy distributions that don't support --no-launch
# Pester 5.x format
# NOTE: This test is slow and only runs with -Full flag

param(
    [bool]$Full = $false
)

BeforeAll {
    # Skip all tests if -Full flag not provided
    if (-not $Full) {
        Write-Host "Skipping LegacyDistro tests (use -Full flag to run)" -ForegroundColor Yellow
        $PSCmdlet.MyInvocation.BoundParameters['Skip'] = $true
        return
    }

    $script:ExampleDir = Join-Path $PSScriptRoot "..\..\examples\legacy-distro"
    # Use Ubuntu-20.04 as it's a well-known legacy distribution
    $script:TestDistro = "Ubuntu-20.04"

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

    # Cleanup any existing legacy distribution installation
    $installedDistros = wsl --list --quiet 2>&1
    if ($LASTEXITCODE -eq 0) {
        $installedDistros = $installedDistros -replace '\x00', ''
        foreach ($line in $installedDistros -split "`r?`n") {
            if ($line.Trim() -eq $script:TestDistro) {
                Write-Host "Removing existing $script:TestDistro installation"
                wsl --unregister $script:TestDistro 2>&1 | Out-Null
                Start-Sleep -Seconds 2
                break
            }
        }
    }
}

AfterAll {
    # Cleanup after all tests (only if tests ran)
    if ($Full) {
        vagrant destroy -f 2>$null | Out-Null
        Pop-Location
    }

    # Note: We intentionally keep the cache for performance
    # Users can manually delete it if needed
}

Describe "Vagrant WSL2 Provider - Legacy Distribution Support" -Skip:(-not $Full) {

    Context "When installing a legacy distribution from scratch" {

        It "Should not have the legacy distribution installed initially" {
            $installedDistros = wsl --list --quiet 2>&1
            $distroFound = $false

            if ($LASTEXITCODE -eq 0) {
                $installedDistros = $installedDistros -replace '\x00', ''
                foreach ($line in $installedDistros -split "`r?`n") {
                    if ($line.Trim() -eq $script:TestDistro) {
                        $distroFound = $true
                        break
                    }
                }
            }

            $distroFound | Should -Be $false
        }

        It "Should successfully install legacy distribution and create cache" -Tag "Slow" {
            # This will:
            # 1. Install Ubuntu-20.04 (launches interactively)
            # 2. Terminate it before user setup
            # 3. Export to cache
            # 4. Unregister the base distribution
            # 5. Import project distribution from cache

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
            $projectFound = $false

            if ($LASTEXITCODE -eq 0) {
                $installedDistros = $installedDistros -replace '\x00', ''
                foreach ($line in $installedDistros -split "`r?`n") {
                    $distroName = $line.Trim()
                    # Legacy distros get timestamped names due to collision detection
                    if ($distroName -match "^$script:TestDistro") {
                        $projectFound = $true
                        break
                    }
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

        It "Should create second VM from cache (faster - no installation)" -Tag "Slow" {
            # This should be faster since cache exists
            $startTime = Get-Date
            vagrant up
            $duration = (Get-Date) - $startTime

            $LASTEXITCODE | Should -Be 0
            # Should be faster than 2 minutes since using cache
            $duration.TotalSeconds | Should -BeLessThan 120
        }

        It "Should have the second VM running" {
            $output = (vagrant status) -join "`n"
            $output | Should -Match "running"
        }

        It "Should be able to SSH into the second VM" {
            $result = vagrant ssh -c "echo 'second vm test'"
            $LASTEXITCODE | Should -Be 0
            $result | Should -Match "second vm test"
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

        It "Should have removed the project distribution" {
            $installedDistros = wsl --list --quiet 2>&1
            if ($LASTEXITCODE -eq 0) {
                $installedDistros = $installedDistros -replace '\x00', ''
                $projectFound = $false

                foreach ($line in $installedDistros -split "`r?`n") {
                    $distroName = $line.Trim()
                    # Check for project distribution
                    if ($distroName -match "^$script:TestDistro") {
                        $projectFound = $true
                        break
                    }
                }

                $projectFound | Should -Be $false
            }
        }

        It "Should keep the cache tar file for future use" {
            $cacheDir = Join-Path $env:USERPROFILE ".vagrant.d\wsl2-cache"
            $cacheTar = Join-Path $cacheDir "$script:TestDistro-vagrant-base.tar"
            Test-Path $cacheTar | Should -Be $true
        }
    }

    Context "When user has legacy distribution already installed (backup/restore scenario)" {

        BeforeAll {
            # Delete the cache to force recreation
            $cacheDir = Join-Path $env:USERPROFILE ".vagrant.d\wsl2-cache"
            $cacheTar = Join-Path $cacheDir "$script:TestDistro-vagrant-base.tar"
            if (Test-Path $cacheTar) {
                Remove-Item $cacheTar -Force
                Write-Host "Removed cache to test backup/restore scenario"
            }

            # Install the legacy distribution as if user has it
            Write-Host "Installing $script:TestDistro to simulate user having it already..."

            # Use wsl --install to get the distribution installed
            # We'll terminate it quickly to avoid interactive setup
            $installJob = Start-Job -ScriptBlock {
                param($distro)
                wsl --install --distribution $distro 2>&1
            } -ArgumentList $script:TestDistro

            # Wait for distribution to appear (max 60 seconds)
            $timeout = 60
            $elapsed = 0
            $distroInstalled = $false

            while ($elapsed -lt $timeout -and -not $distroInstalled) {
                Start-Sleep -Seconds 2
                $elapsed += 2

                $installedDistros = wsl --list --quiet 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $installedDistros = $installedDistros -replace '\x00', ''
                    foreach ($line in $installedDistros -split "`r?`n") {
                        if ($line.Trim() -eq $script:TestDistro) {
                            $distroInstalled = $true
                            break
                        }
                    }
                }
            }

            # Terminate the installation job and the distribution
            Stop-Job -Job $installJob -ErrorAction SilentlyContinue
            Remove-Job -Job $installJob -ErrorAction SilentlyContinue
            wsl --terminate $script:TestDistro 2>&1 | Out-Null
            Start-Sleep -Seconds 2

            if (-not $distroInstalled) {
                throw "Failed to install $script:TestDistro for testing"
            }

            # Modify the distribution to make it "dirty" (simulate user usage)
            Write-Host "Making distribution 'dirty' to simulate user usage..."
            wsl -d $script:TestDistro -u root -- bash -c "echo 'user-data' > /root/.user-marker" 2>&1 | Out-Null
            wsl --terminate $script:TestDistro 2>&1 | Out-Null
        }

        It "Should have the legacy distribution installed before vagrant up" {
            $installedDistros = wsl --list --quiet 2>&1
            $distroFound = $false

            if ($LASTEXITCODE -eq 0) {
                $installedDistros = $installedDistros -replace '\x00', ''
                foreach ($line in $installedDistros -split "`r?`n") {
                    if ($line.Trim() -eq $script:TestDistro) {
                        $distroFound = $true
                        break
                    }
                }
            }

            $distroFound | Should -Be $true
        }

        It "Should verify the distribution is 'dirty' (has user modifications)" {
            $result = wsl -d $script:TestDistro -u root -- bash -c "cat /root/.user-marker 2>/dev/null || echo 'not-found'" 2>&1
            wsl --terminate $script:TestDistro 2>&1 | Out-Null

            $output = ($result -join "`n").Trim()
            $output | Should -Match "user-data"
        }

        It "Should successfully create VM with backup/restore process" -Tag "Slow" {
            # This should:
            # 1. Detect Ubuntu-20.04 is installed (legacy)
            # 2. Backup user's Ubuntu-20.04
            # 3. Unregister Ubuntu-20.04
            # 4. Install fresh Ubuntu-20.04
            # 5. Export to cache
            # 6. Unregister fresh Ubuntu-20.04
            # 7. Restore user's original Ubuntu-20.04
            # 8. Create project VM from cache

            vagrant up
            $LASTEXITCODE | Should -Be 0
        }

        It "Should have restored user's original distribution after caching" {
            # User's original Ubuntu-20.04 should still exist
            $installedDistros = wsl --list --quiet 2>&1
            $distroFound = $false

            if ($LASTEXITCODE -eq 0) {
                $installedDistros = $installedDistros -replace '\x00', ''
                foreach ($line in $installedDistros -split "`r?`n") {
                    if ($line.Trim() -eq $script:TestDistro) {
                        $distroFound = $true
                        break
                    }
                }
            }

            $distroFound | Should -Be $true
        }

        It "Should have preserved user's modifications in original distribution" {
            # The user's original distribution should still have the dirty data
            $result = wsl -d $script:TestDistro -u root -- bash -c "cat /root/.user-marker 2>/dev/null || echo 'not-found'" 2>&1
            wsl --terminate $script:TestDistro 2>&1 | Out-Null

            $output = ($result -join "`n").Trim()
            $output | Should -Match "user-data"
        }

        It "Should have created cache from clean distribution" {
            $cacheDir = Join-Path $env:USERPROFILE ".vagrant.d\wsl2-cache"
            $cacheTar = Join-Path $cacheDir "$script:TestDistro-vagrant-base.tar"
            Test-Path $cacheTar | Should -Be $true
        }

        It "Should have created a separate project distribution from cache" {
            $installedDistros = wsl --list --quiet 2>&1
            $projectFound = $false

            if ($LASTEXITCODE -eq 0) {
                $installedDistros = $installedDistros -replace '\x00', ''
                foreach ($line in $installedDistros -split "`r?`n") {
                    $distroName = $line.Trim()
                    # Project distribution will have timestamp suffix
                    if ($distroName -match "^$script:TestDistro" -and $distroName -ne $script:TestDistro) {
                        $projectFound = $true
                        break
                    }
                }
            }

            $projectFound | Should -Be $true
        }

        It "Should have project VM created (running or stopped)" {
            $output = (vagrant status) -join "`n"
            # VM should exist in either running or stopped state (WSL may auto-stop)
            $output | Should -Match "(running|stopped)"
        }

        It "Should be able to SSH into project VM" {
            $result = vagrant ssh -c "echo 'test'"
            $LASTEXITCODE | Should -Be 0
            $result | Should -Match "test"
        }

        It "Project VM should NOT have user's dirty data (clean from cache)" {
            # The project VM should be clean, not have /root/.user-marker
            $result = vagrant ssh -c "sudo cat /root/.user-marker 2>/dev/null || echo 'not-found'"
            $LASTEXITCODE | Should -Be 0
            ($result -join "`n") | Should -Match "not-found"
        }

        It "Should clean up project VM" {
            vagrant destroy -f
            $LASTEXITCODE | Should -Be 0
        }

        It "Should clean up user's original distribution for final cleanup" {
            wsl --unregister $script:TestDistro 2>&1 | Out-Null
            Start-Sleep -Seconds 2

            # Verify it's gone
            $installedDistros = wsl --list --quiet 2>&1
            $distroFound = $false

            if ($LASTEXITCODE -eq 0) {
                $installedDistros = $installedDistros -replace '\x00', ''
                foreach ($line in $installedDistros -split "`r?`n") {
                    if ($line.Trim() -eq $script:TestDistro) {
                        $distroFound = $true
                        break
                    }
                }
            }

            $distroFound | Should -Be $false
        }
    }
}
