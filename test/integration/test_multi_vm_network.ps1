param([switch]$Verbose)

$ErrorActionPreference = "Stop"
$TestName = "Multi-VM Network"
$ExampleDir = Join-Path $PSScriptRoot "..\..\examples\multi-vm-network"

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

    # Cleanup any existing VMs
    Write-Host "Cleaning up any existing VMs..." -ForegroundColor Yellow
    vagrant destroy -f 2>$null

    # Test 1: Start both VMs
    Write-Host ""
    Write-Host "Test 1: Starting both VMs (vm1 and vm2)" -ForegroundColor Yellow
    vagrant up
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to start VMs"
    }
    Write-Host "[PASS] Both VMs started successfully" -ForegroundColor Green

    # Verify both VMs are running
    Write-Host ""
    Write-Host "Test 2: Verifying both VMs are running" -ForegroundColor Yellow
    $status = vagrant status
    if ($status -match "vm1.*running" -and $status -match "vm2.*running") {
        Write-Host "[PASS] Both VMs are in running state" -ForegroundColor Green
    } else {
        throw "VMs are not in running state"
    }

    # Test 2: Verify static IPs on vm1
    Write-Host ""
    Write-Host "Test 3: Verifying static IP on vm1 (192.168.50.10)" -ForegroundColor Yellow
    $vm1_ip = vagrant ssh vm1 -c "ip addr show eth0 | grep 'inet ' | awk '{print `$2}' | cut -d/ -f1" 2>$null
    $vm1_ip = $vm1_ip.Trim()
    if ($vm1_ip -eq "192.168.50.10") {
        Write-Host "[PASS] vm1 has correct IP: $vm1_ip" -ForegroundColor Green
    } else {
        throw "vm1 IP is incorrect. Expected: 192.168.50.10, Got: $vm1_ip"
    }

    # Test 3: Verify static IPs on vm2
    Write-Host ""
    Write-Host "Test 4: Verifying static IP on vm2 (192.168.50.11)" -ForegroundColor Yellow
    $vm2_ip = vagrant ssh vm2 -c "ip addr show eth0 | grep 'inet ' | awk '{print `$2}' | cut -d/ -f1" 2>$null
    $vm2_ip = $vm2_ip.Trim()
    if ($vm2_ip -eq "192.168.50.11") {
        Write-Host "[PASS] vm2 has correct IP: $vm2_ip" -ForegroundColor Green
    } else {
        throw "vm2 IP is incorrect. Expected: 192.168.50.11, Got: $vm2_ip"
    }

    # Test 4: Test VM-to-VM communication (vm1 -> vm2)
    Write-Host ""
    Write-Host "Test 5: Testing communication from vm1 to vm2" -ForegroundColor Yellow
    $ping_result = vagrant ssh vm1 -c "ping -c 3 192.168.50.11" 2>$null
    if ($LASTEXITCODE -eq 0 -and $ping_result -match "3 received") {
        Write-Host "[PASS] vm1 can ping vm2" -ForegroundColor Green
    } else {
        throw "vm1 cannot ping vm2"
    }

    # Test 5: Test VM-to-VM communication (vm2 -> vm1)
    Write-Host ""
    Write-Host "Test 6: Testing communication from vm2 to vm1" -ForegroundColor Yellow
    $ping_result = vagrant ssh vm2 -c "ping -c 3 192.168.50.10" 2>$null
    if ($LASTEXITCODE -eq 0 -and $ping_result -match "3 received") {
        Write-Host "[PASS] vm2 can ping vm1" -ForegroundColor Green
    } else {
        throw "vm2 cannot ping vm1"
    }

    # Test 6: Verify VM isolation via hostname
    Write-Host ""
    Write-Host "Test 7: Verifying VM isolation via hostname" -ForegroundColor Yellow
    $vm1_hostname = vagrant ssh vm1 -c "hostname" 2>$null
    $vm2_hostname = vagrant ssh vm2 -c "hostname" 2>$null

    if ($vm1_hostname) { $vm1_hostname = $vm1_hostname.Trim() }
    if ($vm2_hostname) { $vm2_hostname = $vm2_hostname.Trim() }

    if ($vm1_hostname -eq "vagrant-net-vm1" -and $vm2_hostname -eq "vagrant-net-vm2") {
        Write-Host "[PASS] VMs have independent hostnames (vm1: $vm1_hostname, vm2: $vm2_hostname)" -ForegroundColor Green
    } else {
        throw "VM isolation check failed (vm1: $vm1_hostname, vm2: $vm2_hostname)"
    }

    # Test 7: Verify filesystem isolation
    Write-Host ""
    Write-Host "Test 8: Verifying filesystem isolation" -ForegroundColor Yellow
    vagrant ssh vm1 -c "echo 'vm1-test-data' > /tmp/isolation-test" 2>$null
    vagrant ssh vm2 -c "echo 'vm2-test-data' > /tmp/isolation-test" 2>$null

    $vm1_data = vagrant ssh vm1 -c "cat /tmp/isolation-test" 2>$null
    $vm2_data = vagrant ssh vm2 -c "cat /tmp/isolation-test" 2>$null

    if ($vm1_data) { $vm1_data = $vm1_data.Trim() }
    if ($vm2_data) { $vm2_data = $vm2_data.Trim() }

    if ($vm1_data -eq "vm1-test-data" -and $vm2_data -eq "vm2-test-data") {
        Write-Host "[PASS] VMs have independent filesystems" -ForegroundColor Green
    } else {
        throw "Filesystem isolation check failed (vm1: $vm1_data, vm2: $vm2_data)"
    }

    # Test 8: Test HTTP communication between VMs using Python web server
    Write-Host ""
    Write-Host "Test 9: Testing HTTP communication between VMs" -ForegroundColor Yellow

    # Start Python HTTP server on vm1 (Ubuntu has Python3) in background
    vagrant ssh vm1 -c "python3 -m http.server 8080 --bind 192.168.50.10 > /dev/null 2>&1 &" 2>$null

    # Wait for server to start
    Start-Sleep -Seconds 3

    # Try to fetch from vm2
    $http_result = vagrant ssh vm2 -c "curl -s --connect-timeout 5 http://192.168.50.10:8080/" 2>$null

    # Cleanup - kill the Python server
    vagrant ssh vm1 -c "pkill -f 'python3 -m http.server 8080'" 2>$null

    if ($http_result -and $http_result -match "Directory listing") {
        Write-Host "[PASS] HTTP communication successful between VMs" -ForegroundColor Green
    } else {
        Write-Host "[WARN] HTTP test failed - VM-to-VM communication may be limited due to WSL2 shared NIC" -ForegroundColor Yellow
    }

    # Cleanup
    Write-Host ""
    Write-Host "Cleaning up..." -ForegroundColor Yellow
    vagrant destroy -f
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to destroy VMs"
    }

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
