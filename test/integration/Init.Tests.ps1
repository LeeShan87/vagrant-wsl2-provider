# Init integration test for Vagrant WSL2 Provider
# Tests: vagrant init workflow
# Pester 5.x format

# Define distribution name - must be script-scoped to be accessible in BeforeAll/AfterAll
$script:DistributionName = "Ubuntu"

# Check if distribution already exists before we start
$installedDistros = wsl --list --quiet 2>&1
$distroAlreadyInstalled = $false

if ($LASTEXITCODE -eq 0) {
    $installedDistros = $installedDistros -replace '\x00', ''
    foreach ($line in $installedDistros -split "`r?`n") {
        if ($line.Trim() -eq $script:DistributionName) {
            $distroAlreadyInstalled = $true
            break
        }
    }
}

# Skip test if distribution already exists
if ($distroAlreadyInstalled) {
    Write-Host "Skipping test: $($script:DistributionName) already exists on this system" -ForegroundColor Yellow
    Write-Host "This test requires a clean system without the test distribution pre-installed" -ForegroundColor Yellow
    $script:SkipTests = $true
    return
}

$script:SkipTests = $false

BeforeAll {
    if ($script:SkipTests) { return }

    $script:ExampleDir = Join-Path $PSScriptRoot "..\..\examples\init"
    $script:DistributionName = "Ubuntu"
    $script:VagrantfilePath = Join-Path $script:ExampleDir "Vagrantfile"

    # Ensure we're in the correct directory
    Push-Location $script:ExampleDir

    # Cleanup any existing instances
    if (Test-Path $script:VagrantfilePath) {
        vagrant destroy -f 2>$null | Out-Null
        Remove-Item $script:VagrantfilePath -Force -ErrorAction SilentlyContinue
    }
}

AfterAll {
    if ($script:SkipTests) { return }

    # Cleanup after all tests
    vagrant destroy -f 2>$null | Out-Null

    # Remove generated Vagrantfile
    if (Test-Path $script:VagrantfilePath) {
        Remove-Item $script:VagrantfilePath -Force -ErrorAction SilentlyContinue
    }

    Pop-Location
}

Describe "Vagrant WSL2 Provider - Init Workflow" -Skip:$script:SkipTests {

    Context "When initializing a new Vagrantfile" {

        It "Should create a Vagrantfile with vagrant init" {
            vagrant init Ubuntu
            $LASTEXITCODE | Should -Be 0
            Test-Path $script:VagrantfilePath | Should -Be $true
        }

        It "Should contain Ubuntu box configuration" {
            $content = Get-Content $script:VagrantfilePath -Raw
            $content | Should -Match 'config\.vm\.box\s*=\s*"Ubuntu"'
        }
    }

    Context "When using the initialized Vagrantfile" {

        It "Should successfully bring up the VM" {
            vagrant up --provider=wsl2
            $LASTEXITCODE | Should -Be 0
        }

        It "Should create WSL distribution using box name" {
            $wslList = (wsl -l -v | Out-String) -replace '\0', ''
            # Distribution name should be the box name (Ubuntu)
            $wslList | Should -Match $script:DistributionName
        }

        It "Should show running status" {
            $status = (vagrant status) -join "`n"
            $status | Should -Match "running"
        }

        It "Should be able to SSH into the VM" {
            $result = vagrant ssh -c "echo 'Hello from Ubuntu'" 2>&1
            $result -join "`n" | Should -Match "Hello from Ubuntu"
        }

        It "Should successfully halt the VM" {
            vagrant halt
            $LASTEXITCODE | Should -Be 0
        }

        It "Should show stopped status after halt" {
            $status = (vagrant status) -join "`n"
            $status | Should -Match "stopped"
        }

        It "Should successfully destroy the VM" {
            vagrant destroy -f
            $LASTEXITCODE | Should -Be 0
        }

        It "Should remove WSL distribution" {
            $wslList = (wsl -l -v | Out-String) -replace '\0', ''
            $wslList | Should -Not -Match $script:DistributionName
        }
    }
}
