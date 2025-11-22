# Docker integration test for Vagrant WSL2 Provider
# Tests Docker installation across multiple distributions
# Quick mode: 3 distributions, Full mode: all distributions
# Pester 5.x format

param(
    [switch]$Full
)

BeforeAll {
    Write-Host "HEllo fromthe test"
    $script:ExampleDir = Join-Path $PSScriptRoot "..\..\examples\docker-test"

    # Quick test distributions (default)
    $script:QuickMachines = @(
        @{ Name = "ubuntu2404"; Distro = "vagrant-docker-ubuntu2404" },
        @{ Name = "debian"; Distro = "vagrant-docker-debian" },
        @{ Name = "almalinux8"; Distro = "vagrant-docker-almalinux8" }
    )

    # All test distributions (comprehensive)
    $script:AllMachines = @(
        @{ Name = "ubuntu2404"; Distro = "vagrant-docker-ubuntu2404" },
        @{ Name = "ubuntu2204"; Distro = "vagrant-docker-ubuntu2204" },
        @{ Name = "ubuntu2004"; Distro = "vagrant-docker-ubuntu2004" },
        @{ Name = "ubuntu"; Distro = "vagrant-docker-ubuntu" },
        @{ Name = "debian"; Distro = "vagrant-docker-debian" },
        @{ Name = "kali"; Distro = "vagrant-docker-kali" },
        @{ Name = "almalinux8"; Distro = "vagrant-docker-almalinux8" },
        @{ Name = "almalinux9"; Distro = "vagrant-docker-almalinux9" },
        @{ Name = "almalinux10"; Distro = "vagrant-docker-almalinux10" },
        @{ Name = "almalinuxkitten10"; Distro = "vagrant-docker-almalinuxkitten10" },
        @{ Name = "fedora42"; Distro = "vagrant-docker-fedora42" },
        @{ Name = "fedora43"; Distro = "vagrant-docker-fedora43" },
        @{ Name = "oraclelinux79"; Distro = "vagrant-docker-oraclelinux79" },
        @{ Name = "oraclelinux810"; Distro = "vagrant-docker-oraclelinux810" },
        @{ Name = "oraclelinux95"; Distro = "vagrant-docker-oraclelinux95" },
        @{ Name = "opensuse"; Distro = "vagrant-docker-opensuse" },
        @{ Name = "opensuseleap156"; Distro = "vagrant-docker-opensuseleap156" },
        @{ Name = "opensuseleap160"; Distro = "vagrant-docker-opensuseleap160" },
        @{ Name = "sle15sp6"; Distro = "vagrant-docker-sle15sp6" },
        @{ Name = "sle15sp7"; Distro = "vagrant-docker-sle15sp7" },
        @{ Name = "sle160"; Distro = "vagrant-docker-sle160" },
        @{ Name = "archlinux"; Distro = "vagrant-docker-archlinux" }
    )

    # Select machines based on Full parameter
    $script:TestMachines = if ($Full) {
        Write-Host "Running FULL Docker test (all $($script:AllMachines.Count) distributions)" -ForegroundColor Cyan
        $script:AllMachines
    } else {
        Write-Host "Running QUICK Docker test ($($script:QuickMachines.Count) distributions)" -ForegroundColor Cyan
        Write-Host "Use -Full parameter to test all distributions" -ForegroundColor Gray
        $script:QuickMachines
    }

    Write-Host ""
    Write-Host "Testing Docker on $($script:TestMachines.Count) distributions:" -ForegroundColor Cyan
    $script:TestMachines | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor White }
    Write-Host ""

    Push-Location $script:ExampleDir

    # Cleanup any existing instances for all machines we'll test
    foreach ($machine in $script:TestMachines) {
        vagrant destroy -f $machine.Name 2>$null | Out-Null
    }
}

AfterAll {
    # Cleanup all test machines
    foreach ($machine in $script:TestMachines) {
        vagrant destroy -f $machine.Name 2>$null | Out-Null
    }
    Pop-Location
}

Describe "Vagrant WSL2 Provider - Docker Support" {

    Context "When testing Docker installation across distributions" {

        It "Should successfully bring up <Name> with Docker" -ForEach $script:TestMachines {
            param($Name, $Distro)
            vagrant up $Name --provider=wsl2
            $LASTEXITCODE | Should -Be 0
        }

        It "Should create WSL distribution for <Name>" -ForEach $script:TestMachines {
            param($Name, $Distro)
            
            $wslList = (wsl -l -v | Out-String) -replace '\0', ''
            $wslList | Should -Match $Distro
        }

        It "Should have Docker service running on <Name>" -ForEach $script:TestMachines {
            param($Name, $Distro)
            $result = vagrant ssh $Name -c "sudo systemctl is-active docker" 2>&1
            $result -join "`n" | Should -Match "active"
        }

        It "Should be able to run hello-world container on <Name>" -ForEach $script:TestMachines {
            param($Name, $Distro)
            $result = vagrant ssh $Name -c "sudo docker run hello-world 2>&1" 2>&1
            $result -join "`n" | Should -Match "Hello from Docker"
        }

        It "Should have Docker version installed on <Name>" -ForEach $script:TestMachines {
            param($Name, $Distro)
            $result = vagrant ssh $Name -c "sudo docker --version" 2>&1
            $LASTEXITCODE | Should -Be 0
            $result -join "`n" | Should -Match "Docker version"
        }

        It "Should successfully destroy <Name>" -ForEach $script:TestMachines {
            param($Name, $Distro)
            vagrant destroy -f $Name
            $LASTEXITCODE | Should -Be 0
        }

        It "Should remove WSL distribution for <Name>" -ForEach $script:TestMachines {
            param($Name, $Distro)
            $wslList = (wsl -l -v | Out-String) -replace '\0', ''
            $wslList | Should -Not -Match $Distro
        }
    }
}
