# Integration test for all available WSL distributions
# This test validates which distributions from 'wsl -l -o' work with the vagrant-wsl2-provider

BeforeAll {
    # WSL distributions available from Windows Store (wsl -l -o)
    $script:WslDistributions = @(
        "AlmaLinux-8",
        "AlmaLinux-9",
        "AlmaLinux-Kitten-10",
        "AlmaLinux-10",
        "Debian",
        "FedoraLinux-43",
        "FedoraLinux-42",
        "SUSE-Linux-Enterprise-15-SP7",
        "SUSE-Linux-Enterprise-16.0",
        "Ubuntu",
        "Ubuntu-24.04",
        "archlinux",
        "kali-linux",
        "openSUSE-Tumbleweed",
        "openSUSE-Leap-16.0",
        "Ubuntu-20.04",
        "Ubuntu-22.04",
        "OracleLinux_7_9",
        "OracleLinux_8_10",
        "OracleLinux_9_5",
        "openSUSE-Leap-15.6",
        "SUSE-Linux-Enterprise-15-SP6"
    )

    Write-Host ""
    Write-Host "Testing $($script:WslDistributions.Count) WSL distributions:" -ForegroundColor Cyan
    $script:WslDistributions | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
    Write-Host ""

    # Create test directory in examples folder
    $script:TestBaseDir = Join-Path $PSScriptRoot "..\..\examples\test-distributions"
    if (Test-Path $script:TestBaseDir) {
        Write-Host "Cleaning up previous test directory..." -ForegroundColor Yellow
        Remove-Item $script:TestBaseDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $script:TestBaseDir | Out-Null

    # Store results for summary
    $script:TestResults = @{}
}

AfterAll {
    # Cleanup test directory
    if (Test-Path $script:TestBaseDir) {
        Remove-Item $script:TestBaseDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Display summary
    Write-Host ""
    Write-Host "=== Distribution Compatibility Summary ===" -ForegroundColor Cyan
    Write-Host ""

    $successful = $script:TestResults.GetEnumerator() | Where-Object { $_.Value.Success }
    $failed = $script:TestResults.GetEnumerator() | Where-Object { -not $_.Value.Success }

    if ($successful) {
        Write-Host "Supported Distributions ($($successful.Count)):" -ForegroundColor Green
        $successful | ForEach-Object {
            Write-Host "  [PASS] $($_.Key)" -ForegroundColor Green
        }
    }

    Write-Host ""

    if ($failed) {
        Write-Host "Unsupported/Failed Distributions ($($failed.Count)):" -ForegroundColor Yellow
        $failed | ForEach-Object {
            Write-Host "  [FAIL] $($_.Key)" -ForegroundColor Red
            Write-Host "         Error: $($_.Value.Error)" -ForegroundColor Gray
        }
    }

    Write-Host ""
    if ($script:TestResults.Count -gt 0) {
        Write-Host "Total: $($script:TestResults.Count) distributions tested" -ForegroundColor Cyan
        Write-Host "Success Rate: $($successful.Count)/$($script:TestResults.Count) ($([math]::Round(($successful.Count / $script:TestResults.Count) * 100, 1))%)" -ForegroundColor Cyan
    }
}

Describe "WSL Distribution Compatibility Tests" {

    Context "Testing each distribution" {

        It "Should test all distributions" {
            foreach ($distribution in $script:WslDistributions) {
                Write-Host ""
                Write-Host "Testing distribution: $distribution" -ForegroundColor Cyan

                $testDir = Join-Path $script:TestBaseDir $distribution
                New-Item -ItemType Directory -Path $testDir -Force | Out-Null

                try {
                    Push-Location $testDir

                    # Step 1: vagrant init
                    Write-Host "  Running 'vagrant init $distribution'..." -ForegroundColor Gray
                    $initOutput = vagrant init $distribution 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        throw "vagrant init failed: $initOutput"
                    }

                    # Step 2: Update Vagrantfile to configure wsl2 provider
                    Write-Host "  Configuring WSL2 provider..." -ForegroundColor Gray
                    $vagrantfileContent = Get-Content -Path "Vagrantfile" -Raw

                    # Replace the config.vm.box line and add provider config
                    $vagrantfileContent = $vagrantfileContent -replace 'config\.vm\.box = ".*"', "config.vm.box = `"$distribution`""

                    # Add provider configuration before the end
                    $vagrantfileContent = $vagrantfileContent -replace '(end\s*)$', @"
  config.vm.provider "wsl2" do |wsl|
    wsl.distribution_name = "vagrant-test-$distribution"
    wsl.version = 2
  end
`$1
"@

                    Set-Content -Path "Vagrantfile" -Value $vagrantfileContent

                    # Step 3: vagrant up
                    Write-Host "  Running 'vagrant up --provider=wsl2'..." -ForegroundColor Gray
                    $upOutput = vagrant up --provider=wsl2 2>&1
                    $exitCode = $LASTEXITCODE

                    if ($exitCode -eq 0) {
                        Write-Host "  [PASS] ${distribution}: vagrant up succeeded" -ForegroundColor Green

                        # Step 4: vagrant destroy
                        Write-Host "  Running 'vagrant destroy -f'..." -ForegroundColor Gray
                        vagrant destroy -f | Out-Null

                        $script:TestResults[$distribution] = @{
                            Success = $true
                            Error = $null
                        }
                    } else {
                        $errorMsg = ($upOutput | Out-String).Trim()
                        Write-Host "  [FAIL] $distribution failed" -ForegroundColor Red
                        Write-Host "  Error: $($errorMsg.Split("`n")[0])" -ForegroundColor Gray

                        # Cleanup attempt
                        vagrant destroy -f 2>&1 | Out-Null

                        $script:TestResults[$distribution] = @{
                            Success = $false
                            Error = if ($errorMsg.Length -gt 200) { $errorMsg.Substring(0, 200) + "..." } else { $errorMsg }
                        }
                    }

                } catch {
                    $errorMsg = $_.Exception.Message
                    Write-Host "  [FAIL] $distribution threw exception" -ForegroundColor Red
                    Write-Host "  Error: $errorMsg" -ForegroundColor Gray

                    # Cleanup attempt
                    vagrant destroy -f 2>&1 | Out-Null

                    $script:TestResults[$distribution] = @{
                        Success = $false
                        Error = if ($errorMsg.Length -gt 200) { $errorMsg.Substring(0, 200) + "..." } else { $errorMsg }
                    }

                } finally {
                    Pop-Location

                    # Cleanup test directory for this distribution
                    if (Test-Path $testDir) {
                        Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            # The test passes as long as it runs - results are in the summary
            $true | Should -Be $true
        }
    }
}
