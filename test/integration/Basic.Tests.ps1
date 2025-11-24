# Basic integration test for Vagrant WSL2 Provider
# Tests: vagrant up, ssh, destroy
# Pester 5.x format

BeforeAll {
    $script:ExampleDir = Join-Path $PSScriptRoot "..\..\examples\basic"
    $script:DistributionName = "vagrant-wsl2-basic"

    # Ensure we're in the correct directory
    Push-Location $script:ExampleDir

    # Cleanup any existing instances
    vagrant destroy -f 2>$null | Out-Null
}

AfterAll {
    # Cleanup after all tests
    vagrant destroy -f 2>$null | Out-Null
    Pop-Location
}

Describe "Vagrant WSL2 Provider - Basic Operations" {

    Context "When creating a new VM" {
        It "Should successfully run 'vagrant up --provider=wsl2'" {
            vagrant up --provider=wsl2
            $LASTEXITCODE | Should -Be 0
        }

        It "Should show valid state in 'vagrant status'" {
            $status = (vagrant status) -join "`n"
            $status | Should -Match "running|stopped"
        }

        It "Should create WSL distribution 'vagrant-wsl2-basic'" {
            $wslList = (wsl -l -v | Out-String) -replace '\0', ''
            $wslList | Should -Match $script:DistributionName
        }
    }

    Context "When accessing the VM" {
        It "Should return valid SSH configuration" {
            # Give Vagrant a moment to update state
            Start-Sleep -Seconds 1
            $sshConfig = (vagrant ssh-config 2>&1) -join "`n"
            $LASTEXITCODE | Should -Be 0
            $sshConfig | Should -Match "Host default"
        }

        It "Should execute commands via 'vagrant ssh -c'" {
            $sshOutput = vagrant ssh -c "echo 'SSH test successful'" 2>&1
            $LASTEXITCODE | Should -Be 0
            $sshOutput | Should -Match "SSH test successful"
        }

        It "Should handle SSH commands with pipes" {
            $output = vagrant ssh -c "echo 'test' | grep 'test'" 2>&1
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match "test"
        }

        It "Should start a background process (Python web server)" {
            # Try to start Python HTTP server in background
            $output = vagrant ssh -ic "python3 -m http.server 8888 > /dev/null 2>&1 &" | Out-Null
            $LASTEXITCODE | Should -Be 0

            # Give it a moment to start
            Start-Sleep -Seconds 2

            # Check if the process is running
            $psOutput = vagrant ssh -c "ps aux | grep 'http.server' | grep -v grep" 2>&1
            $psOutput | Should -Match "http.server"
        }

        It "Should clean up background processes" {
            # Kill the web server
            vagrant ssh -c "pkill -f 'http.server'" 2>&1 | Out-Null
            Start-Sleep -Seconds 1

            # Verify it's gone
            $psOutput = vagrant ssh -c "ps aux | grep 'http.server' | grep -v grep" 2>&1
            $psOutput | Should -Not -Match "http.server"
        }
    }

    Context "When managing VM state" {
        It "Should successfully halt the VM" {
            vagrant halt
            $LASTEXITCODE | Should -Be 0
        }

        It "Should show correct state after halt (not running)" {
            Start-Sleep -Seconds 2
            $status = (vagrant status) -join "`n"

            # After halt, should NOT show "running"
            $status | Should -Not -Match "running"
        }

        It "Should successfully start VM again after halt" {
            vagrant up --provider=wsl2
            $LASTEXITCODE | Should -Be 0
        }

        It "Should show valid state after restart" {
            Start-Sleep -Seconds 2
            $status = (vagrant status) -join "`n"

            # Should show either running or stopped (WSL2 auto-sleeps)
            # But definitely NOT "not created"
            $status | Should -Match "running|stopped"
            $status | Should -Not -Match "not created"
        }
    }

    Context "When destroying the VM" {
        It "Should successfully run 'vagrant destroy -f'" {
            vagrant destroy -f
            $LASTEXITCODE | Should -Be 0
        }

        It "Should remove the WSL distribution" {
            $wslList = (wsl -l -v | Out-String) -replace '\0', ''
            $wslList | Should -Not -Match $script:DistributionName
        }
    }
}
