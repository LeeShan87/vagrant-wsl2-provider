# Pester 5.x integration test for Vagrant WSL2 Provider - Data Disk functionality
# Tests VHD creation, mounting, persistence, and cleanup

# Check admin rights early for informative message
$isAdminCheck = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdminCheck) {
    Write-Host ""
    Write-Host "=== Data Disk Test SKIPPED ===" -ForegroundColor Yellow
    Write-Host "Reason: Administrator privileges required for data disk tests" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Data disk features require:" -ForegroundColor Gray
    Write-Host "  - VHD creation (New-VHD cmdlet)" -ForegroundColor Gray
    Write-Host "  - WSL disk mounting (wsl --mount)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To run this test, please restart PowerShell as Administrator" -ForegroundColor Cyan
    Write-Host ""
}

BeforeAll {
    $script:ExampleDir = Join-Path $PSScriptRoot "..\..\examples\data-disk"
    $script:ErrorActionPreference = "Stop"

    # Store admin status for skip condition
    $script:isAdmin = $isAdminCheck

    # Always push location, even if skipping (for proper cleanup)
    Push-Location $script:ExampleDir

    if (-not $script:isAdmin) {
        return
    }

    # Cleanup before tests
    vagrant destroy -f 2>$null

    # Clean up any leftover persistent VHD
    $persistentVhd = "test-data-disk.vhdx"
    if (Test-Path $persistentVhd) {
        Remove-Item $persistentVhd -Force 2>$null
    }
}

AfterAll {
    # Cleanup after all tests
    vagrant destroy -f 2>$null

    # Clean up persistent VHD
    $persistentVhd = "test-data-disk.vhdx"
    if (Test-Path $persistentVhd) {
        Remove-Item $persistentVhd -Force 2>$null
    }

    # Always pop location
    Pop-Location
}

Describe "Vagrant WSL2 Provider - Data Disk" -Skip:(-not $isAdminCheck) -Tag @('RequiresAdmin') {

    Context "When creating VM with data disks" {

        It "Should successfully run 'vagrant up --provider=wsl2'" {
            vagrant up --provider=wsl2
            $LASTEXITCODE | Should -Be 0 -Because "vagrant up should succeed"
        }

        It "Should create all VHD files (2 default + 1 persistent)" {
            $vhdPath1 = ".vagrant\machines\default\wsl2\data-disk-0.vhdx"
            $vhdPath2 = ".vagrant\machines\default\wsl2\data-disk-1.vhd"
            $vhdPath3 = "test-data-disk.vhdx"

            Test-Path $vhdPath1 | Should -Be $true -Because "first default VHD should exist"
            Test-Path $vhdPath2 | Should -Be $true -Because "second default VHD should exist"
            Test-Path $vhdPath3 | Should -Be $true -Because "persistent VHD should exist"

            # Verify file sizes are reasonable (not empty)
            (Get-Item $vhdPath1).Length | Should -BeGreaterThan 0
            (Get-Item $vhdPath2).Length | Should -BeGreaterThan 0
            (Get-Item $vhdPath3).Length | Should -BeGreaterThan 0
        }

        It "Should mount data disks in the VM" {
            $mountCheck = vagrant ssh -c "mount | grep /mnt/data" 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "mount command should succeed"
            $mountCheck | Should -Not -BeNullOrEmpty -Because "data disks should be mounted"
        }

        It "Should have multiple block devices (sda + data disks)" {
            $lsblkOutput = vagrant ssh -c "lsblk | grep sd" 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "lsblk command should succeed"

            $deviceCount = ($lsblkOutput -split "`n" | Where-Object { $_ -match "^sd[a-z]" }).Count
            $deviceCount | Should -BeGreaterOrEqual 4 -Because "should have system disk + 3 data disks"
        }
    }

    Context "When writing data to disks" {

        It "Should write data to first disk" {
            vagrant ssh -c "echo 'test data from disk 1' | sudo tee /mnt/data1/test-persistence.txt > /dev/null" 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "write to first disk should succeed"
        }

        It "Should write data to second disk" {
            vagrant ssh -c "echo 'test data from disk 2' | sudo tee /mnt/data2/test-persistence.txt > /dev/null" 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "write to second disk should succeed"
        }

        It "Should write data to persistent disk" {
            vagrant ssh -c "echo 'persistent data from disk 3' | sudo tee /mnt/data3/test-persistence.txt > /dev/null" 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "write to persistent disk should succeed"
        }

        It "Should show all data filesystems mounted" {
            $dfOutput = vagrant ssh -c "df -h | grep /mnt/data" 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "df command should succeed"

            $mountCount = ($dfOutput -split "`n" | Where-Object { $_ -match "/mnt/data" }).Count
            $mountCount | Should -BeGreaterOrEqual 3 -Because "should have 3 data filesystems"
        }
    }

    Context "When destroying and recreating VM" {

        It "Should successfully destroy VM" {
            vagrant destroy -f 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "vagrant destroy should succeed"
        }

        It "Should clean up default VHD files after destroy" {
            $vhdPath1 = ".vagrant\machines\default\wsl2\data-disk-0.vhdx"
            $vhdPath2 = ".vagrant\machines\default\wsl2\data-disk-1.vhd"

            Test-Path $vhdPath1 | Should -Be $false -Because "default VHD 1 should be deleted"
            Test-Path $vhdPath2 | Should -Be $false -Because "default VHD 2 should be deleted"
        }

        It "Should preserve persistent VHD after destroy" {
            $vhdPath3 = "test-data-disk.vhdx"
            Test-Path $vhdPath3 | Should -Be $true -Because "persistent VHD should survive destroy"
        }

        It "Should recreate VM successfully" {
            vagrant up 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "vagrant up after destroy should succeed"
        }

        It "Should create new default VHD files on recreation" {
            $vhdPath1 = ".vagrant\machines\default\wsl2\data-disk-0.vhdx"
            $vhdPath2 = ".vagrant\machines\default\wsl2\data-disk-1.vhd"

            Test-Path $vhdPath1 | Should -Be $true -Because "new default VHD 1 should be created"
            Test-Path $vhdPath2 | Should -Be $true -Because "new default VHD 2 should be created"
        }

        It "Should have clean default disks (no old data)" {
            $data1Check = vagrant ssh -c "test -f /mnt/data1/test-persistence.txt && echo exists || echo clean" 2>&1
            $LASTEXITCODE | Should -Be 0
            $data1Check | Should -Match "clean" -Because "new default disk should not have old data"
        }

        It "Should retain data on persistent disk across destroy/up cycle" {
            $data3Check = vagrant ssh -c "cat /mnt/data3/test-persistence.txt 2>/dev/null" 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "read from persistent disk should succeed"
            $data3Check | Should -Match "persistent data from disk 3" -Because "persistent disk should retain data"
        }
    }
}
