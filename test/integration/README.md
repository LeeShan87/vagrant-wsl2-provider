# Integration Tests

PowerShell-based integration tests for the Vagrant WSL2 Provider.

## Running Tests

### All Tests
```bash
rake test
# or
pwsh test/integration/run_all_tests.ps1
```

### Individual Tests
```bash
rake test_basic
rake test_snapshot
# or
pwsh test/integration/test_basic.ps1
pwsh test/integration/test_snapshot.ps1
```

## Test Coverage

### test_basic.ps1
Tests core functionality:
- `vagrant up --provider=wsl2`
- `vagrant status`
- `vagrant ssh`
- `vagrant destroy`
- Distribution cleanup verification

### test_snapshot.ps1
Tests snapshot functionality:
- `vagrant snapshot save`
- `vagrant snapshot list`
- `vagrant snapshot restore`
- `vagrant snapshot delete`
- `vagrant snapshot push/pop`

## Requirements

- Windows 10/11 with WSL2 enabled
- Vagrant installed
- vagrant-wsl2-provider plugin installed
- PowerShell 5.1 or later

## Adding New Tests

Create a new file `test_<name>.ps1` following this template:

```powershell
param([switch]$Verbose)

$ErrorActionPreference = "Stop"
$TestName = "YourTestName"
$ExampleDir = Join-Path $PSScriptRoot "..\..\examples\your-example"

Write-Host ""
Write-Host "=== Running $TestName Test ===" -ForegroundColor Cyan

try {
    Push-Location $ExampleDir

    # Your tests here
    Write-Host "[PASS] test description" -ForegroundColor Green

    exit 0
} catch {
    Write-Host "=== $TestName Test FAILED ===" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}
```

The test will be automatically picked up by `run_all_tests.ps1`.
