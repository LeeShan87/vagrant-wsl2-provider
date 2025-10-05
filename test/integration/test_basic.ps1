# Basic integration test for Vagrant WSL2 Provider
# Tests: vagrant up, ssh, destroy

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$TestName = "Basic"
$ExampleDir = Join-Path $PSScriptRoot "..\..\examples\basic"

Write-Host ""
Write-Host "=== Running $TestName Test ===" -ForegroundColor Cyan

try {
    Push-Location $ExampleDir

    # Cleanup any existing instances
    Write-Host "Cleaning up..." -ForegroundColor Yellow
    vagrant destroy -f 2>$null

    # Test: vagrant up
    Write-Host ""
    Write-Host "Test: vagrant up --provider=wsl2" -ForegroundColor Yellow
    vagrant up --provider=wsl2
    if ($LASTEXITCODE -ne 0) {
        throw "vagrant up failed with exit code $LASTEXITCODE"
    }
    Write-Host "[PASS] vagrant up succeeded" -ForegroundColor Green

    # Test: vagrant status
    Write-Host ""
    Write-Host "Test: vagrant status" -ForegroundColor Yellow
    $status = vagrant status
    if ($status -match "running|stopped") {
        Write-Host "[PASS] vagrant status shows valid state" -ForegroundColor Green
    } else {
        throw "Invalid vagrant status output"
    }

    # Test: Verify WSL distribution exists
    Write-Host ""
    Write-Host "Test: WSL distribution exists" -ForegroundColor Yellow
    $wslList = (wsl -l -v | Out-String) -replace '\0', ''
    if ($wslList -match "vagrant-wsl2-basic") {
        Write-Host "[PASS] WSL distribution created successfully" -ForegroundColor Green
    } else {
        Write-Host "WSL distributions found:" -ForegroundColor Yellow
        Write-Host $wslList -ForegroundColor Yellow
        throw "WSL distribution 'vagrant-wsl2-basic' not found in wsl -l"
    }

    # Test: vagrant ssh-config
    Write-Host ""
    Write-Host "Test: vagrant ssh-config" -ForegroundColor Yellow
    # Give Vagrant a moment to update state after up
    Start-Sleep -Seconds 1
    $sshConfig = vagrant ssh-config 2>&1
    if ($LASTEXITCODE -eq 0) {
        if ($sshConfig -match "wsl-native") {
            Write-Host "[PASS] SSH configuration available" -ForegroundColor Green
        } else {
            throw "SSH configuration missing wsl-native hostname"
        }
    } else {
        Write-Host "Warning: ssh-config output: $sshConfig" -ForegroundColor Yellow
        throw "vagrant ssh-config failed with exit code $LASTEXITCODE"
    }

    # Test: vagrant ssh -c command
    Write-Host ""
    Write-Host "Test: vagrant ssh -c" -ForegroundColor Yellow
    $sshOutput = vagrant ssh -c "echo 'SSH test successful'" 2>&1
    if ($LASTEXITCODE -eq 0) {
        if ($sshOutput -match "SSH test successful") {
            Write-Host "[PASS] SSH command execution works" -ForegroundColor Green
        } else {
            Write-Host "SSH output: $sshOutput" -ForegroundColor Yellow
            throw "SSH command did not produce expected output"
        }
    } else {
        throw "vagrant ssh -c failed with exit code $LASTEXITCODE"
    }

    # Test: vagrant destroy
    Write-Host ""
    Write-Host "Test: vagrant destroy" -ForegroundColor Yellow
    vagrant destroy -f
    if ($LASTEXITCODE -ne 0) {
        throw "vagrant destroy failed with exit code $LASTEXITCODE"
    }
    Write-Host "[PASS] vagrant destroy succeeded" -ForegroundColor Green

    # Verify distribution is removed
    Write-Host ""
    Write-Host "Verifying distribution removal..." -ForegroundColor Yellow
    $distributions = (wsl -l -v | Out-String) -replace '\0', ''
    if ($distributions -match "vagrant-wsl2-basic") {
        throw "Distribution still exists after destroy"
    }
    Write-Host "[PASS] Distribution removed successfully" -ForegroundColor Green

    Write-Host ""
    Write-Host "=== $TestName Test PASSED ===" -ForegroundColor Green
    exit 0

} catch {
    Write-Host ""
    Write-Host "=== $TestName Test FAILED ===" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red

    # Cleanup on failure
    vagrant destroy -f 2>$null

    exit 1
} finally {
    Pop-Location
}
