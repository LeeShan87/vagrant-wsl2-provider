# Provisioners integration test for Vagrant WSL2 Provider
# Tests: shell, file, and ansible_local provisioners separately
# Chef and Salt provisioners only run with -Full flag
# Pester 5.x format

param(
    [switch]$Full
)

Describe "Vagrant WSL2 Provider - Shell Provisioner" {
    BeforeAll {
        $script:ExampleDir = Join-Path $PSScriptRoot "..\..\examples\provisioners\shell"
        $script:DistributionName = "vagrant-wsl2-shell-test"

        Push-Location $script:ExampleDir
        vagrant destroy -f 2>$null | Out-Null
    }

    AfterAll {
        vagrant destroy -f 2>$null | Out-Null
        Pop-Location
    }

    Context "When provisioning with shell scripts" {
        It "Should successfully run 'vagrant up --provider=wsl2'" {
            vagrant up --provider=wsl2
            $LASTEXITCODE | Should -Be 0
        }

        It "Should create WSL distribution" {
            $wslList = (wsl -l -v | Out-String) -replace '\0', ''
            $wslList | Should -Match $script:DistributionName
        }

        It "Should have created shell-test.txt file" {
            $result = vagrant ssh -c "test -f /home/vagrant/shell-test.txt && echo 'exists'" 2>&1
            $result -join "`n" | Should -Match "exists"
        }

        It "Should have correct content in shell-test.txt" {
            $result = vagrant ssh -c "cat /home/vagrant/shell-test.txt" 2>&1
            $result -join "`n" | Should -Match "shell-test"
        }

        It "Should have installed htop package" {
            $result = vagrant ssh -c "which htop" 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        It "Should have created whoami-test.txt as vagrant user" {
            $result = vagrant ssh -c "cat /home/vagrant/whoami-test.txt" 2>&1
            $result -join "`n" | Should -Match "vagrant"
        }

        It "Should successfully reprovision" {
            vagrant provision
            $LASTEXITCODE | Should -Be 0
        }

        It "Should successfully destroy the VM" {
            vagrant destroy -f
            $LASTEXITCODE | Should -Be 0
        }
    }
}

Describe "Vagrant WSL2 Provider - File Provisioner" {
    BeforeAll {
        $script:ExampleDir = Join-Path $PSScriptRoot "..\..\examples\provisioners\file"
        $script:DistributionName = "vagrant-wsl2-file-test"

        Push-Location $script:ExampleDir
        vagrant destroy -f 2>$null | Out-Null
    }

    AfterAll {
        vagrant destroy -f 2>$null | Out-Null
        Pop-Location
    }

    Context "When provisioning with file uploads" {
        It "Should successfully run 'vagrant up --provider=wsl2'" {
            vagrant up --provider=wsl2
            $LASTEXITCODE | Should -Be 0
        }

        It "Should create WSL distribution" {
            $wslList = (wsl -l -v | Out-String) -replace '\0', ''
            $wslList | Should -Match $script:DistributionName
        }

        It "Should have uploaded test-file.txt" {
            $result = vagrant ssh -c "test -f /home/vagrant/uploaded-file-test.txt && echo 'exists'" 2>&1
            $result -join "`n" | Should -Match "exists"
        }

        It "Should have correct content in uploaded file" {
            $result = vagrant ssh -c "cat /home/vagrant/uploaded-file-test.txt" 2>&1
            $result -join "`n" | Should -Match "File provisioner test completed successfully"
        }

        It "Should successfully reprovision" {
            vagrant provision
            $LASTEXITCODE | Should -Be 0
        }

        It "Should successfully destroy the VM" {
            vagrant destroy -f
            $LASTEXITCODE | Should -Be 0
        }
    }
}

Describe "Vagrant WSL2 Provider - Ansible Local Provisioner" {
    BeforeAll {
        $script:ExampleDir = Join-Path $PSScriptRoot "..\..\examples\provisioners\ansible"
        $script:DistributionName = "vagrant-wsl2-ansible-test"

        Push-Location $script:ExampleDir
        vagrant destroy -f 2>$null | Out-Null
    }

    AfterAll {
        vagrant destroy -f 2>$null | Out-Null
        Pop-Location
    }

    Context "When provisioning with Ansible" {
        It "Should successfully run 'vagrant up --provider=wsl2'" {
            vagrant up --provider=wsl2
            $LASTEXITCODE | Should -Be 0
        }

        It "Should create WSL distribution" {
            $wslList = (wsl -l -v | Out-String) -replace '\0', ''
            $wslList | Should -Match $script:DistributionName
        }

        It "Should have created ansible-test directory" {
            $result = vagrant ssh -c "test -d /home/vagrant/ansible-test && echo 'exists'" 2>&1
            $result -join "`n" | Should -Match "exists"
        }

        It "Should have created ansible-test.txt file" {
            $result = vagrant ssh -c "test -f /home/vagrant/ansible-test/ansible-test.txt && echo 'exists'" 2>&1
            $result -join "`n" | Should -Match "exists"
        }

        It "Should have correct content in ansible-test.txt" {
            $result = vagrant ssh -c "cat /home/vagrant/ansible-test/ansible-test.txt" 2>&1
            $result -join "`n" | Should -Match "Ansible provisioner working on WSL2"
        }

        It "Should have installed htop package via Ansible" {
            $result = vagrant ssh -c "which htop" 2>&1
            $LASTEXITCODE | Should -Be 0
            $result -join "`n" | Should -Match "/usr/bin/htop"
        }

        It "Should successfully reprovision" {
            vagrant provision
            $LASTEXITCODE | Should -Be 0
        }

        It "Should successfully destroy the VM" {
            vagrant destroy -f
            $LASTEXITCODE | Should -Be 0
        }
    }
}

Describe "Vagrant WSL2 Provider - Chef Solo Provisioner" -Tag "KnownIssue" -Skip:(-not $Full) {
    BeforeAll {
        $script:ExampleDir = Join-Path $PSScriptRoot "..\..\examples\provisioners\chef"
        $script:DistributionName = "vagrant-wsl2-chef-test"

        Push-Location $script:ExampleDir
        vagrant destroy -f 2>$null | Out-Null
    }

    AfterAll {
        vagrant destroy -f 2>$null | Out-Null
        Pop-Location
    }

    Context "When provisioning with Chef Solo" {
        It "Should successfully run 'vagrant up --provider=wsl2'" {
            vagrant up --provider=wsl2
            $LASTEXITCODE | Should -Be 0
        }

        It "Should create WSL distribution" {
            $wslList = (wsl -l -v | Out-String) -replace '\0', ''
            $wslList | Should -Match $script:DistributionName
        }

        It "Should have created chef-test.txt file" {
            $result = vagrant ssh -c "test -f /home/vagrant/chef-test.txt && echo 'exists'" 2>&1
            $result -join "`n" | Should -Match "exists"
        }

        It "Should have correct content in chef-test.txt" {
            $result = vagrant ssh -c "cat /home/vagrant/chef-test.txt" 2>&1
            $result -join "`n" | Should -Match "Hello from Chef on WSL2"
        }

        It "Should have created chef-test directory" {
            $result = vagrant ssh -c "test -d /home/vagrant/chef-test && echo 'exists'" 2>&1
            $result -join "`n" | Should -Match "exists"
        }

        It "Should have installed tree package" {
            $result = vagrant ssh -c "which tree" 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        It "Should successfully reprovision" {
            vagrant provision
            $LASTEXITCODE | Should -Be 0
        }

        It "Should successfully destroy the VM" {
            vagrant destroy -f
            $LASTEXITCODE | Should -Be 0
        }
    }
}

Describe "Vagrant WSL2 Provider - SaltStack Provisioner" -Tag "KnownIssue" -Skip:(-not $Full) {
    BeforeAll {
        $script:ExampleDir = Join-Path $PSScriptRoot "..\..\examples\provisioners\salt"
        $script:DistributionName = "vagrant-wsl2-salt-test"

        Push-Location $script:ExampleDir
        vagrant destroy -f 2>$null | Out-Null
    }

    AfterAll {
        vagrant destroy -f 2>$null | Out-Null
        Pop-Location
    }

    Context "When provisioning with SaltStack" {
        It "Should successfully run 'vagrant up --provider=wsl2'" {
            vagrant up --provider=wsl2
            $LASTEXITCODE | Should -Be 0
        }

        It "Should create WSL distribution" {
            $wslList = (wsl -l -v | Out-String) -replace '\0', ''
            $wslList | Should -Match $script:DistributionName
        }

        It "Should have created salt-test.txt file" {
            $result = vagrant ssh -c "test -f /home/vagrant/salt-test.txt && echo 'exists'" 2>&1
            $result -join "`n" | Should -Match "exists"
        }

        It "Should have correct content in salt-test.txt" {
            $result = vagrant ssh -c "cat /home/vagrant/salt-test.txt" 2>&1
            $result -join "`n" | Should -Match "Hello from SaltStack on WSL2"
        }

        It "Should have created salt-test directory" {
            $result = vagrant ssh -c "test -d /home/vagrant/salt-test && echo 'exists'" 2>&1
            $result -join "`n" | Should -Match "exists"
        }

        It "Should have installed curl package" {
            $result = vagrant ssh -c "which curl" 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        It "Should successfully reprovision" {
            vagrant provision
            $LASTEXITCODE | Should -Be 0
        }

        It "Should successfully destroy the VM" {
            vagrant destroy -f
            $LASTEXITCODE | Should -Be 0
        }
    }
}
