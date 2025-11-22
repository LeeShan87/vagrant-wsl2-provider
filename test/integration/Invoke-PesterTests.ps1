# Centralized Pester test runner
# Usage:
#   .\Invoke-PesterTests.ps1                           # Run all tests
#   .\Invoke-PesterTests.ps1 -TestFile Basic           # Run specific test
#   .\Invoke-PesterTests.ps1 -TestFile AllDistributions -Full  # Run with parameters

param(
    [string]$TestFile = $null,
    [ValidateSet('Detailed', 'Normal', 'Minimal')]
    [string]$Output = 'Detailed',
    [switch]$Full  # For AllDistributions test: run all distributions instead of quick subset
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

# Build Pester configuration
$config = New-PesterConfiguration
$config.Output.Verbosity = $Output
$config.Run.PassThru = $true

# Pass parameters to test scripts using New-PesterContainer
if ($Full) {
    # Create container with data parameter
    $container = New-PesterContainer -Path $TestPath -Data @{ Full = $true }
    $config.Run.Container = $container
} else {
    # No parameters needed
    $config.Run.Path = $TestPath
}

# Run Pester tests
$result = Invoke-Pester -Configuration $config

# Exit with appropriate code
exit $result.FailedCount
