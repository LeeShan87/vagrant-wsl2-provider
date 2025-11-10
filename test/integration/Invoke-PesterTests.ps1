# Centralized Pester test runner
# Usage:
#   .\Invoke-PesterTests.ps1                    # Run all tests
#   .\Invoke-PesterTests.ps1 -TestFile Basic    # Run specific test

param(
    [string]$TestFile = $null,
    [ValidateSet('Detailed', 'Normal', 'Minimal')]
    [string]$Output = 'Detailed'
)

$ErrorActionPreference = "Stop"

# Ensure Pester 5.x is imported
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

$TestPath = $PSScriptRoot

if ($TestFile) {
    # Run specific test file
    $TestPath = Join-Path $TestPath "$TestFile.Tests.ps1"
    if (-not (Test-Path $TestPath)) {
        Write-Error "Test file not found: $TestPath"
        exit 1
    }
}

# Run Pester tests
$result = Invoke-Pester -Path $TestPath -Output $Output -PassThru

# Exit with appropriate code
exit $result.FailedCount
