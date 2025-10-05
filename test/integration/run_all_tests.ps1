# Run all integration tests for Vagrant WSL2 Provider

$ErrorActionPreference = "Stop"
$TestsDir = $PSScriptRoot
$Failed = 0
$Passed = 0

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Vagrant WSL2 Provider Integration Tests" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get all test scripts
$TestScripts = Get-ChildItem -Path $TestsDir -Filter "test_*.ps1" | Where-Object { $_.Name -ne "run_all_tests.ps1" }

foreach ($TestScript in $TestScripts) {
    Write-Host "Running: $($TestScript.Name)" -ForegroundColor Yellow

    & $TestScript.FullName

    if ($LASTEXITCODE -eq 0) {
        $Passed++
    } else {
        $Failed++
    }

    Write-Host ""
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Passed: $Passed" -ForegroundColor Green
Write-Host "Failed: $Failed" -ForegroundColor $(if ($Failed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($Failed -gt 0) {
    Write-Host "OVERALL: FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "OVERALL: PASSED" -ForegroundColor Green
    exit 0
}
