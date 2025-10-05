# Snapshot integration test for Vagrant WSL2 Provider
# Tests: snapshot save, list, restore, delete

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$TestName = "Snapshot"
$ExampleDir = Join-Path $PSScriptRoot "..\..\examples\snapshot"

Write-Host ""
Write-Host "=== Running $TestName Test ===" -ForegroundColor Cyan

try {
    Push-Location $ExampleDir

    # Cleanup any existing instances
    Write-Host "Cleaning up..." -ForegroundColor Yellow
    vagrant destroy -f 2>$null

    # Setup: Create VM
    Write-Host ""
    Write-Host "Setup: Creating VM..." -ForegroundColor Yellow
    vagrant up --provider=wsl2
    if ($LASTEXITCODE -ne 0) {
        throw "vagrant up failed"
    }

    # Test: snapshot save
    Write-Host ""
    Write-Host "Test: vagrant snapshot save" -ForegroundColor Yellow
    vagrant snapshot save test-snapshot-1
    if ($LASTEXITCODE -ne 0) {
        throw "snapshot save failed"
    }
    Write-Host "[PASS] snapshot save succeeded" -ForegroundColor Green

    # Test: snapshot list
    Write-Host ""
    Write-Host "Test: vagrant snapshot list" -ForegroundColor Yellow
    $snapshots = vagrant snapshot list
    if ($snapshots -match "test-snapshot-1") {
        Write-Host "[PASS] snapshot appears in list" -ForegroundColor Green
    } else {
        throw "Snapshot not found in list"
    }

    # Create a second snapshot
    Write-Host ""
    Write-Host "Creating second snapshot..." -ForegroundColor Yellow
    vagrant snapshot save test-snapshot-2
    if ($LASTEXITCODE -ne 0) {
        throw "second snapshot save failed"
    }

    # Test: multiple snapshots listed
    $snapshots = vagrant snapshot list
    if (($snapshots -match "test-snapshot-1") -and ($snapshots -match "test-snapshot-2")) {
        Write-Host "[PASS] multiple snapshots listed" -ForegroundColor Green
    } else {
        throw "Not all snapshots found in list"
    }

    # Test: snapshot restore
    Write-Host ""
    Write-Host "Test: vagrant snapshot restore" -ForegroundColor Yellow
    vagrant snapshot restore test-snapshot-1
    if ($LASTEXITCODE -ne 0) {
        throw "snapshot restore failed"
    }
    Write-Host "[PASS] snapshot restore succeeded" -ForegroundColor Green

    # Test: snapshot delete
    Write-Host ""
    Write-Host "Test: vagrant snapshot delete" -ForegroundColor Yellow
    vagrant snapshot delete test-snapshot-2
    if ($LASTEXITCODE -ne 0) {
        throw "snapshot delete failed"
    }

    # Verify deletion
    $snapshots = vagrant snapshot list
    if (($snapshots -match "test-snapshot-1") -and ($snapshots -notmatch "test-snapshot-2")) {
        Write-Host "[PASS] snapshot deleted successfully" -ForegroundColor Green
    } else {
        throw "Snapshot deletion verification failed"
    }

    # Test: snapshot push/pop
    Write-Host ""
    Write-Host "Test: vagrant snapshot push/pop" -ForegroundColor Yellow
    vagrant snapshot push
    if ($LASTEXITCODE -ne 0) {
        throw "snapshot push failed"
    }
    Write-Host "[PASS] snapshot push succeeded" -ForegroundColor Green

    vagrant snapshot pop
    if ($LASTEXITCODE -ne 0) {
        throw "snapshot pop failed"
    }
    Write-Host "[PASS] snapshot pop succeeded" -ForegroundColor Green

    # Cleanup
    Write-Host ""
    Write-Host "Cleaning up..." -ForegroundColor Yellow
    vagrant destroy -f
    if ($LASTEXITCODE -ne 0) {
        throw "vagrant destroy failed"
    }

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
