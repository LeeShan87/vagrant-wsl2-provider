# Pester 5.x integration test for Vagrant WSL2 Provider - Networking functionality
# Tests: private network, static IP configuration, port forwarding

# Check admin rights early for informative message
$isAdminCheck = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdminCheck) {
    Write-Host ""
    Write-Host "=== Networking Test SKIPPED ===" -ForegroundColor Yellow
    Write-Host "Reason: Administrator privileges required for networking tests" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Networking features require administrator privileges for:" -ForegroundColor Gray
    Write-Host "  - Creating virtual network adapters" -ForegroundColor Gray
    Write-Host "  - Configuring static IP addresses" -ForegroundColor Gray
    Write-Host "  - Port forwarding configuration" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To run this test, please restart PowerShell as Administrator" -ForegroundColor Cyan
    Write-Host ""
}

BeforeAll {
    $script:ExampleDir = Join-Path $PSScriptRoot "..\..\examples\networking"
    $script:ErrorActionPreference = "Stop"

    # Store admin status for skip condition
    $script:isAdmin = $isAdminCheck

    # Always push location, even if skipping (for proper cleanup)
    Push-Location $script:ExampleDir

    if (-not $script:isAdmin) {
        return
    }

    # Cleanup before tests
    vagrant destroy -f 2>$null | Out-Null
}

AfterAll {
    # Cleanup after all tests
    vagrant destroy -f 2>$null | Out-Null

    # Always pop location
    Pop-Location
}

Describe "Vagrant WSL2 Provider - Networking" -Skip:(-not $isAdminCheck) -Tag @('RequiresAdmin') {

    Context "When creating VM with network configuration" {

        It "Should successfully start VM with private network and port forwarding" {
            vagrant up
            $LASTEXITCODE | Should -Be 0 -Because "vagrant up should succeed"
        }
    }

    Context "When verifying static IP configuration" {

        It "Should configure static IP 192.168.33.10 on eth0" {
            $ipCheck = (wsl -d vagrant-wsl2-networking-demo -- ip addr show eth0) -join "`n"
            $ipCheck | Should -Match "192.168.33.10" -Because "static IP should be configured"
        }

        It "Should be accessible via static IP 192.168.33.10" {
            $response = Invoke-WebRequest -Uri "http://192.168.33.10" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
            $response.StatusCode | Should -Be 200 -Because "VM should respond on static IP 192.168.33.10"
        }

        It "Should be accessible via second static IP 1.2.3.4" {
            $response = Invoke-WebRequest -Uri "http://1.2.3.4" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
            $response.StatusCode | Should -Be 200 -Because "VM should respond on static IP 1.2.3.4"
        }
    }

    Context "When verifying port forwarding" {

        It "Should be accessible via port forwarding localhost:8080 -> guest:80" {
            $response = Invoke-WebRequest -Uri "http://localhost:8080" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
            $response.StatusCode | Should -Be 200 -Because "port forwarding should work"
        }
    }
}
