# Vagrant WSL2 Provider Examples

This directory contains example configurations and manual testing scenarios for the Vagrant WSL2 provider.

## Examples

### Basic
The simplest possible WSL2 provider configuration.

```bash
cd basic
vagrant up --provider=wsl2
vagrant ssh
vagrant destroy -f
```

### Snapshot
Demonstrates snapshot functionality for saving and restoring VM state.

```bash
cd snapshot
vagrant up --provider=wsl2
vagrant snapshot save clean-state
vagrant ssh -c "touch /tmp/test-file"
vagrant snapshot restore clean-state
vagrant snapshot list
vagrant destroy -f
```

### Provisioners
Advanced example with multiple provisioners (shell, file, ansible_local).

```bash
cd provisioners
vagrant up --provider=wsl2
vagrant provision
vagrant destroy -f
```

### Docker Test
Example with Docker and systemd support.

```bash
cd docker-test
vagrant up --provider=wsl2
vagrant ssh -c "docker ps"
vagrant destroy -f
```

### Test Distros
Multiple Linux distribution configurations for compatibility testing.

```bash
cd test-distros
# Edit Vagrantfile to select distribution
vagrant up --provider=wsl2
vagrant destroy -f
```

## Cleanup

To remove all WSL2 distributions created by these examples:

```powershell
# WARNING: This removes ALL WSL distributions matching vagrant-wsl2-*
wsl -l | Select-String -Pattern 'vagrant-wsl2-' | ForEach-Object {
    $name = $_.Line -replace '\*', '' -replace '\s*\(.*\)', '' -replace '\0', ''
    if ($name.Trim()) { wsl --unregister $name.Trim() }
}
```

## Manual Testing Workflow

These examples serve as manual integration tests. For each example:

1. Start clean: `vagrant destroy -f`
2. Test creation: `vagrant up --provider=wsl2`
3. Test functionality: `vagrant ssh`, `vagrant provision`, etc.
4. Test snapshots (if applicable)
5. Test cleanup: `vagrant destroy -f`
6. Verify removal: `wsl -l` (distribution should be gone)
