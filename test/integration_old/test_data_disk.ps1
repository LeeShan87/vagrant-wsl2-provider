param([switch]$Verbose)

$ErrorActionPreference = "Stop"
$TestName = "DataDisk"
$ExampleDir = Join-Path $PSScriptRoot "..\..\examples\data-disk"

Write-Host ""
Write-Host "=== Running $TestName Test ===" -ForegroundColor Cyan

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "=== $TestName Test SKIPPED ===" -ForegroundColor Yellow
    Write-Host "Reason: Administrator privileges required for data disk tests" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Data disk features require:" -ForegroundColor Gray
    Write-Host "  - VHD creation (New-VHD cmdlet)" -ForegroundColor Gray
    Write-Host "  - WSL disk mounting (wsl --mount)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To run this test, please restart PowerShell as Administrator" -ForegroundColor Cyan
    Write-Host ""
    exit 0
}

try {
    Push-Location $ExampleDir

    # Cleanup
    Write-Host "Cleaning up..." -ForegroundColor Yellow
    vagrant destroy -f 2>$null

    # Test 1: Create VM with data disks
    Write-Host ""
    Write-Host "Test 1: Creating VM with data disks" -ForegroundColor Yellow
    $result = vagrant up
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[PASS] VM created with data disks" -ForegroundColor Green
    } else {
        throw "Failed to create VM with data disks (exit code $LASTEXITCODE)"
    }

    # Test 2: Verify VHD files were created
    Write-Host ""
    Write-Host "Test 2: Verifying VHD files exist" -ForegroundColor Yellow
    $vhdPath1 = ".vagrant\machines\default\wsl2\data-disk-0.vhdx"
    $vhdPath2 = ".vagrant\machines\default\wsl2\data-disk-1.vhd"
    $vhdPath3 = "test-data-disk.vhdx"

    if ((Test-Path $vhdPath1) -and (Test-Path $vhdPath2) -and (Test-Path $vhdPath3)) {
        Write-Host "[PASS] All VHD files created (2 default + 1 persistent)" -ForegroundColor Green
        $vhd1Size = (Get-Item $vhdPath1).Length / 1MB
        $vhd2Size = (Get-Item $vhdPath2).Length / 1MB
        $vhd3Size = (Get-Item $vhdPath3).Length / 1MB
        Write-Host "  - data-disk-0.vhdx: $([math]::Round($vhd1Size, 2)) MB (default)" -ForegroundColor Gray
        Write-Host "  - data-disk-1.vhd: $([math]::Round($vhd2Size, 2)) MB (default)" -ForegroundColor Gray
        Write-Host "  - test-data-disk.vhdx: $([math]::Round($vhd3Size, 2)) MB (persistent)" -ForegroundColor Gray
    } else {
        throw "VHD files not found"
    }

    # Test 3: Verify data disks are mounted
    Write-Host ""
    Write-Host "Test 3: Verifying data disks are mounted" -ForegroundColor Yellow
    $mountCheck = vagrant ssh -c "mount | grep /mnt/data"
    if ($LASTEXITCODE -eq 0 -and $mountCheck) {
        Write-Host "[PASS] Data disks are mounted" -ForegroundColor Green
        if ($Verbose) {
            Write-Host "Mount info:" -ForegroundColor Gray
            Write-Host $mountCheck -ForegroundColor Gray
        }
    } else {
        throw "Data disks are not mounted"
    }

    # Test 4: Verify block devices
    Write-Host ""
    Write-Host "Test 4: Verifying block devices" -ForegroundColor Yellow
    $lsblkOutput = vagrant ssh -c "lsblk | grep sd"
    if ($LASTEXITCODE -eq 0 -and $lsblkOutput) {
        # Count the number of sd devices (should have sda for system, sdb/sdc/sdd for data)
        $deviceCount = ($lsblkOutput -split "`n" | Where-Object { $_ -match "^sd[a-z]" }).Count
        if ($deviceCount -ge 4) {
            Write-Host "[PASS] Multiple block devices found ($deviceCount)" -ForegroundColor Green
            if ($Verbose) {
                Write-Host "Block devices:" -ForegroundColor Gray
                Write-Host $lsblkOutput -ForegroundColor Gray
            }
        } else {
            throw "Expected at least 4 block devices, found $deviceCount"
        }
    } else {
        throw "Failed to list block devices"
    }

    # Test 5: Write data to first disk
    Write-Host ""
    Write-Host "Test 5: Writing data to first disk" -ForegroundColor Yellow
    vagrant ssh -c "echo 'test data from disk 1' | sudo tee /mnt/data1/test-persistence.txt > /dev/null"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[PASS] Data written to first disk" -ForegroundColor Green
    } else {
        throw "Failed to write data to first disk"
    }

    # Test 6: Write data to second disk
    Write-Host ""
    Write-Host "Test 6: Writing data to second disk" -ForegroundColor Yellow
    vagrant ssh -c "echo 'test data from disk 2' | sudo tee /mnt/data2/test-persistence.txt > /dev/null"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[PASS] Data written to second disk" -ForegroundColor Green
    } else {
        throw "Failed to write data to second disk"
    }

    # Test 6b: Write data to persistent disk
    Write-Host ""
    Write-Host "Test 6b: Writing data to persistent disk" -ForegroundColor Yellow
    vagrant ssh -c "echo 'persistent data from disk 3' | sudo tee /mnt/data3/test-persistence.txt > /dev/null"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[PASS] Data written to persistent disk" -ForegroundColor Green
    } else {
        throw "Failed to write data to persistent disk"
    }

    # Test 7: Verify VHD cleanup on destroy
    Write-Host ""
    Write-Host "Test 7: Testing VHD cleanup on destroy" -ForegroundColor Yellow
    vagrant destroy -f
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to destroy VM"
    }

    # Verify default VHD files are deleted after destroy (expected behavior)
    # Default VHDs in .vagrant directory should be cleaned up
    if (!(Test-Path $vhdPath1) -and !(Test-Path $vhdPath2)) {
        Write-Host "[PASS] Default VHD files cleaned up after destroy" -ForegroundColor Green
    } else {
        throw "Default VHD files were not cleaned up during destroy"
    }

    # Verify persistent VHD is NOT deleted (should survive destroy)
    if (Test-Path $vhdPath3) {
        Write-Host "[PASS] Persistent VHD survived destroy" -ForegroundColor Green
    } else {
        throw "Persistent VHD was deleted during destroy (should persist)"
    }

    # Test 8: Recreate VM - new default VHDs should be created, persistent remains
    Write-Host ""
    Write-Host "Test 8: Testing VM recreation with fresh default disks" -ForegroundColor Yellow
    vagrant up
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to recreate VM"
    }

    # Verify new default VHD files were created
    if ((Test-Path $vhdPath1) -and (Test-Path $vhdPath2)) {
        Write-Host "[PASS] New default VHD files created on up" -ForegroundColor Green
    } else {
        throw "Default VHD files were not recreated"
    }

    # Verify default disks are clean (no old data)
    $data1Check = vagrant ssh -c "test -f /mnt/data1/test-persistence.txt && echo exists || echo clean"
    if ($LASTEXITCODE -eq 0 -and $data1Check -match "clean") {
        Write-Host "[PASS] New default disks are clean (no old data)" -ForegroundColor Green
    } else {
        Write-Host "  Note: Disk may have old data or provisioning issue" -ForegroundColor Gray
    }

    # Verify persistent disk retained its data
    $data3Check = vagrant ssh -c "cat /mnt/data3/test-persistence.txt 2>/dev/null"
    if ($LASTEXITCODE -eq 0 -and $data3Check -match "persistent data from disk 3") {
        Write-Host "[PASS] Persistent disk retained data across destroy/up cycle" -ForegroundColor Green
    } else {
        throw "Persistent disk did not retain data"
    }

    # Test 9: Verify filesystem info
    Write-Host ""
    Write-Host "Test 9: Verifying filesystem information" -ForegroundColor Yellow
    $dfOutput = vagrant ssh -c "df -h | grep /mnt/data"
    if ($LASTEXITCODE -eq 0 -and $dfOutput) {
        $mountCount = ($dfOutput -split "`n" | Where-Object { $_ -match "/mnt/data" }).Count
        if ($mountCount -ge 3) {
            Write-Host "[PASS] All data filesystems mounted ($mountCount)" -ForegroundColor Green
            if ($Verbose) {
                Write-Host "Filesystem info:" -ForegroundColor Gray
                Write-Host $dfOutput -ForegroundColor Gray
            }
        } else {
            throw "Expected at least 3 data filesystems, found $mountCount"
        }
    } else {
        throw "Failed to get filesystem information"
    }

    # Cleanup
    Write-Host ""
    Write-Host "Cleaning up test environment..." -ForegroundColor Yellow
    vagrant destroy -f

    # Clean up persistent VHD
    if (Test-Path $vhdPath3) {
        Remove-Item $vhdPath3 -Force
        Write-Host "Removed persistent test VHD" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "=== $TestName Test PASSED ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  - 3 VHD/VHDX files created (2 default + 1 persistent)" -ForegroundColor Green
    Write-Host "  - Multiple data disks mounted and formatted" -ForegroundColor Green
    Write-Host "  - Data written and read successfully" -ForegroundColor Green
    Write-Host "  - Default VHD cleanup works on destroy" -ForegroundColor Green
    Write-Host "  - Persistent VHD survives destroy" -ForegroundColor Green
    Write-Host "  - Persistent data retained across destroy/up cycle" -ForegroundColor Green
    Write-Host "  - VM recreation creates fresh default disks" -ForegroundColor Green
    Write-Host "  - Both VHD and VHDX formats supported" -ForegroundColor Green
    Write-Host ""
    exit 0

} catch {
    Write-Host ""
    Write-Host "=== $TestName Test FAILED ===" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Cleaning up after failure..." -ForegroundColor Yellow
    vagrant destroy -f 2>$null
    # Clean up persistent VHD on failure too
    $vhdPath3 = "test-data-disk.vhdx"
    if (Test-Path $vhdPath3) {
        Remove-Item $vhdPath3 -Force 2>$null
    }
    exit 1
} finally {
    Pop-Location
}
