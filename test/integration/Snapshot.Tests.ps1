# Pester 5.x integration test for Vagrant WSL2 Provider - Snapshot functionality
# Tests: snapshot save, list, restore, delete, push, pop

BeforeAll {
    $script:ExampleDir = Join-Path $PSScriptRoot "..\..\examples\snapshot"
    $script:ErrorActionPreference = "Stop"

    Push-Location $script:ExampleDir

    # Cleanup before tests
    vagrant destroy -f 2>$null | Out-Null
}

AfterAll {
    # Cleanup after all tests
    # Note: May fail if VHD files are locked by WSL - this is expected
    vagrant destroy -f 2>$null | Out-Null

    # Give WSL a moment to release file locks
    Start-Sleep -Seconds 2

    Pop-Location
}

Describe "Vagrant WSL2 Provider - Snapshot" {

    Context "When setting up VM for snapshot tests" {

        It "Should successfully create VM with 'vagrant up --provider=wsl2'" {
            vagrant up --provider=wsl2
            $LASTEXITCODE | Should -Be 0 -Because "vagrant up should succeed"
        }
    }

    Context "When saving snapshots" {

        It "Should successfully save first snapshot" {
            vagrant snapshot save test-snapshot-1
            $LASTEXITCODE | Should -Be 0 -Because "snapshot save should succeed"
        }

        It "Should list the saved snapshot" {
            $snapshots = (vagrant snapshot list) -join "`n"
            $snapshots | Should -Match "test-snapshot-1" -Because "saved snapshot should appear in list"
        }

        It "Should successfully save second snapshot" {
            vagrant snapshot save test-snapshot-2
            $LASTEXITCODE | Should -Be 0 -Because "second snapshot save should succeed"
        }

        It "Should list both snapshots" {
            $snapshots = (vagrant snapshot list) -join "`n"
            $snapshots | Should -Match "test-snapshot-1" -Because "first snapshot should still be listed"
            $snapshots | Should -Match "test-snapshot-2" -Because "second snapshot should be listed"
        }
    }

    Context "When restoring snapshots" {

        It "Should successfully restore first snapshot" {
            vagrant snapshot restore test-snapshot-1
            $LASTEXITCODE | Should -Be 0 -Because "snapshot restore should succeed"
        }
    }

    Context "When deleting snapshots" {

        It "Should successfully delete second snapshot" {
            vagrant snapshot delete test-snapshot-2
            $LASTEXITCODE | Should -Be 0 -Because "snapshot delete should succeed"
        }

        It "Should show first snapshot still exists after deleting second" {
            $snapshots = (vagrant snapshot list) -join "`n"
            $snapshots | Should -Match "test-snapshot-1" -Because "first snapshot should still exist"
            $snapshots | Should -Not -Match "test-snapshot-2" -Because "second snapshot should be deleted"
        }
    }

    Context "When using snapshot push/pop" {

        It "Should successfully push a snapshot" {
            vagrant snapshot push
            $LASTEXITCODE | Should -Be 0 -Because "snapshot push should succeed"
        }

        It "Should successfully pop a snapshot" {
            vagrant snapshot pop
            $LASTEXITCODE | Should -Be 0 -Because "snapshot pop should succeed"
        }
    }

    Context "When cleaning up" {

        It "Should successfully destroy VM" {
            vagrant destroy -f
            $LASTEXITCODE | Should -Be 0 -Because "vagrant destroy should succeed"
        }
    }
}
