param([switch]$Verbose)

$ErrorActionPreference = "Stop"
$TestName = "Networking"
$ExampleDir = Join-Path $PSScriptRoot "..\..\examples\networking"

Write-Host ""
Write-Host "=== Running $TestName Test ===" -ForegroundColor Cyan

# Check for administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "=== $TestName Test SKIPPED ===" -ForegroundColor Yellow
    Write-Host "This test requires administrator privileges" -ForegroundColor Yellow
    Write-Host "Please run PowerShell as Administrator to execute this test" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

try {
    Push-Location $ExampleDir

    # Cleanup
    Write-Host "Cleaning up..." -ForegroundColor Yellow
    vagrant destroy -f 2>$null

    # Test: Start VM with network configuration
    Write-Host ""
    Write-Host "Test: Starting VM with private network and port forwarding" -ForegroundColor Yellow
    vagrant up
    if ($LASTEXITCODE -ne 0) {
        throw "vagrant up failed with exit code $LASTEXITCODE"
    }
    Write-Host "[PASS] VM started successfully" -ForegroundColor Green

    # Test: Check static IP is configured
    Write-Host ""
    Write-Host "Test: Verify static IP 192.168.33.10 is configured" -ForegroundColor Yellow
    $ipCheck = wsl -d vagrant-wsl2-networking-demo -- ip addr show eth0
    if ($ipCheck -match "192.168.33.10") {
        Write-Host "[PASS] Static IP 192.168.33.10 is configured" -ForegroundColor Green
    } else {
        throw "Static IP 192.168.33.10 not found"
    }

    # Test: Access VM via static IP from host
    Write-Host ""
    Write-Host "Test: Access VM via static IP 192.168.33.10" -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri "http://192.168.33.10" -TimeoutSec 5 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host "[PASS] VM accessible via static IP 192.168.33.10" -ForegroundColor Green
        } else {
            throw "Unexpected status code: $($response.StatusCode)"
        }
    } catch {
        Write-Host "[FAIL] Cannot access VM via static IP: $_" -ForegroundColor Red
        throw
    }

    # Test: Access VM via second static IP 1.2.3.4
    Write-Host ""
    Write-Host "Test: Access VM via static IP 1.2.3.4" -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri "http://1.2.3.4" -TimeoutSec 5 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host "[PASS] VM accessible via static IP 1.2.3.4" -ForegroundColor Green
        } else {
            throw "Unexpected status code: $($response.StatusCode)"
        }
    } catch {
        Write-Host "[FAIL] Cannot access VM via second static IP: $_" -ForegroundColor Red
        throw
    }

    # Test: Access VM via port forwarding on localhost:8080
    Write-Host ""
    Write-Host "Test: Access VM via port forwarding localhost:8080 -> guest:80" -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080" -TimeoutSec 5 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host "[PASS] VM accessible via port forwarding localhost:8080" -ForegroundColor Green
        } else {
            throw "Unexpected status code: $($response.StatusCode)"
        }
    } catch {
        Write-Host "[FAIL] Cannot access VM via port forwarding: $_" -ForegroundColor Red
        throw
}

    # Cleanup
    Write-Host ""
    Write-Host "Cleaning up..." -ForegroundColor Yellow
    vagrant destroy -f

    Write-Host ""
    Write-Host "=== $TestName Test PASSED ===" -ForegroundColor Green
    exit 0

} catch {
    Write-Host ""
    Write-Host "=== $TestName Test FAILED ===" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    vagrant destroy -f 2>$null
    exit 1
} finally {
    Pop-Location
}
