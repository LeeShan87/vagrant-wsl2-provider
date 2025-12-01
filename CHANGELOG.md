# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2025-12-01

### Fixed
- Distribution names now persist across Vagrant commands (fixes #8)
- `vagrant ssh` and other commands now remember auto-generated distribution names
- `vagrant halt` properly shows "stopped" status instead of waking up the distribution
- State checking no longer wakes up stopped distributions
- `vagrant ssh` commands now silently auto-start stopped distributions without verbose output

### Changed
- Distribution names default to box name (e.g., "Ubuntu") instead of random timestamp
- Added collision detection: appends timestamp if box name already exists as a distribution
- Added `wsl.name` as a convenience alias for `wsl.distribution_name`
- SSH commands now accept WSL2's auto-shutdown behavior and start distributions silently when needed

### Added
- Silent distribution startup for SSH commands to prevent output pollution
- `EnsureRunning` action for transparent VM wake-up on SSH access
- Export existing WSL2 distributions to cache for modern distributions (supporting `--name` flag)
- Removed dirty OS check before vagrant up
- Automatic handling for legacy distributions (Ubuntu 20.04/22.04, OracleLinux, etc.) via install -> terminate -> export flow
- Future-proof blocklist approach: only 7 legacy distributions listed, new distributions automatically get modern treatment
- User's original distributions are preserved (not unregistered) when exporting to cache

## [0.4.0] - 2025-11-24

### Changed
- Complete rewrite of WSL2 communicator for improved reliability
- Removed base64 command encoding in favor of direct `wsl --exec bash` execution
- Improved error handling with proper Vagrant error classes and exit code checking
- Enhanced stderr filtering to remove harmless WSL2-specific warnings

### Added
- Custom `vagrant ssh` command with WSL2-specific bash flag support
- Compound flag support: `-cli`, `-lic`, `-lc`, `-ic` for convenient bash flag combinations
- `-l` flag: Use login shell (sources `~/.bash_profile`, `~/.profile`)
- `-i` flag: Use interactive shell (enables job control for background processes)
- Background process support using `-i` flag with proper job control
- WSL command reference documentation in [docs/wsl2-command-cheat-sheet.md](docs/wsl2-command-cheat-sheet.md)
- Better logging and debug output throughout communicator
- Private network support with static IP configuration
- Port forwarding support via Windows netsh portproxy
- Administrator privilege checking for network operations
- Windows routing setup for static IP access between VMs
- Network configuration examples in `examples/networking/`
- Multi-VM network example with detailed README in `examples/multi-vm-network/`
- Integration test for networking functionality (requires admin privileges)
- **Pester 5.x testing framework** for comprehensive integration testing
- Centralized test runner (`Invoke-PesterTests.ps1`) with flexible test selection
- Distribution coverage tests across multiple WSL2 distributions
- Docker integration tests covering installation across various distributions
- Provisioner tests (shell, file, Ansible, Chef, Salt)
- Expanded provisioner examples with individual Vagrantfiles per provisioner type
- Rake tasks for running specific test suites

### Fixed
- Background processes now work correctly with `vagrant ssh -i "command &"`
- Stderr warnings (`screen size is bogus`, job control messages) are now properly filtered
- Command execution with pipes and redirections works reliably
- Exit code propagation from WSL commands to Vagrant
- SSH command output streaming works correctly with real-time output

### SSH Features
- Execute commands with custom bash flags: `vagrant ssh -cli "python3 -m http.server &"`
- Run background processes: `vagrant ssh -i "long-running-command &"`
- Login shell with interactive mode: `vagrant ssh -li` (for interactive SSH session)
- Standard command execution: `vagrant ssh -c "echo hello"` (uses default `-lc` flags)
- Help text available via `vagrant ssh --help` with descriptions for all flags

### Network Features
- Configure static IPs using `config.vm.network "private_network", ip: "192.168.33.10"`
- Port forwarding using `config.vm.network "forwarded_port", guest: 80, host: 8080`
- Persistent network configuration across VM restarts
- VM-to-VM communication via static IP addresses
- Windows host access to VMs via port forwarding
- Clear warnings when administrator privileges are missing
- Public network (bridged mode) warning - not supported due to WSL2 architecture

### Network Configuration
```ruby
# Static IP for inter-VM communication
config.vm.network "private_network", ip: "192.168.33.10"

# Port forwarding for Windows host access
config.vm.network "forwarded_port", guest: 80, host: 8080
config.vm.network "forwarded_port", guest: 443, host: 8443, host_ip: "127.0.0.1"
```

### SSH Usage Examples
```bash
# Standard command execution (default -lc flags)
vagrant ssh -c "echo hello"

# Background process with interactive shell
vagrant ssh -i "python3 -m http.server 8000 &"

# Compound flags for convenience
vagrant ssh -cli "nohup long-running-command > output.log &"

# Login interactive shell
vagrant ssh -li "source ~/.bashrc && my-command"
```

### WSL2 Networking Limitations
- **Administrator privileges required**: Network configuration (routes, port forwarding) requires running Vagrant as Administrator
- **Shared base IP**: All WSL2 distributions share the same underlying IP address due to single Hyper-V VM architecture
- **Static IPs for inter-VM only**: Static IPs work for VM-to-VM communication but not for individual Windows host access
- **Port forwarding for host access**: Use port forwarding to access VMs from Windows host
- **Public network not supported**: Bridged networking unavailable due to WSL2's shared virtual switch

### Technical Details
- Windows routes created using `route add` for static IP routing
- Port forwarding configured using `netsh interface portproxy`
- Routes and port forwards are non-persistent (removed on Windows restart)
- Re-applied automatically on each `vagrant up`
- WSL commands executed via `wsl --distribution <name> -u vagrant --exec bash <flags> <command>`
- Bash flags parsed from command string for flexible execution modes
- Compound flags preprocessed before OptionParser to ensure correct argument parsing
- **Testing infrastructure**: Pester 5.x framework with modular test files
- Integration tests run real Vagrant commands against actual WSL2 distributions
- Test organization: `Basic.Tests.ps1`, `Snapshot.Tests.ps1`, `DataDisk.Tests.ps1`, `Networking.Tests.ps1`, `MultiVmNetwork.Tests.ps1`, `Provisioners.Tests.ps1`, `Docker.Tests.ps1`, `AllDistributions.Tests.ps1`
- Rake integration for easy test execution: `rake test`, `rake test_basic`, `rake test_snapshot`, etc.

## [0.3.0] - 2025-11-01

### Added
- Persistent data disk support with VHD/VHDX formats
- Multiple data disk support per VM
- Automatic VHD/VHDX creation using PowerShell New-VHD
- Support for both VHD (VirtualBox-compatible) and VHDX formats
- Data disk mounting using `wsl --mount --vhd`
- Smart mounting detection (skips admin-requiring operations when disks already mounted)
- Automatic unmounting on VM destroy to prevent file locks
- Distinction between ephemeral disks (deleted on destroy) and persistent disks (custom paths)
- Integration test for data disk functionality with admin privilege detection
- Placeholder integration tests for future features (docker, provisioners, distros)
- Example configuration in `examples/data-disk/`

### Features
- Configure data disks using `data_disk` block in Vagrantfile
- Create new VHD/VHDX files with specified size
- Attach existing VHD/VHDX files from other providers (e.g., VirtualBox, VMware)
- Default disks stored in `.vagrant/` directory are automatically cleaned up on destroy
- Custom-path disks survive `vagrant destroy` for true data persistence
- Automatic partitioning, formatting (ext4), and mounting via provisioning
- Support for custom disk paths and formats
- VHD format determined by file extension (.vhd vs .vhdx)
- Smart admin privilege handling: required for initial setup, optional for subsequent startups

### Configuration
```ruby
# Ephemeral disk (deleted on destroy)
wsl.data_disk do |disk|
  disk.size = 10         # Size in GB
  disk.format = 'vhdx'   # 'vhd' or 'vhdx' (default: 'vhdx')
end

# Persistent disk (survives destroy)
wsl.data_disk do |disk|
  disk.path = '../my-data.vhdx'  # Custom path
end
```

### Requirements
- **Administrator privileges required for initial setup**: VHD creation (`New-VHD`) and WSL disk mounting (`wsl --mount`) require running Vagrant as Administrator
- After initial `vagrant up` and `vagrant halt`, subsequent `vagrant up` commands do not require admin (disks remain mounted at host level)
- `vagrant destroy` will unmount disks, requiring admin again for next `vagrant up`
- Windows 10 Build 20211+ or Windows 11 for `wsl --mount --vhd` support

### Technical Details
- WSL2 data disks appear as `/dev/sde` and higher (system disks use sda-sdd)
- Provisioning script automatically detects and formats data disks
- Mounts at `/mnt/data1`, `/mnt/data2`, etc.
- Integration tests gracefully skip when not running as Administrator

## [0.2.0] - 2025-10-30

### Added
- Full snapshot support (save, restore, list, delete)
- Support for `vagrant snapshot push/pop` commands
- `vagrant ssh -c` command execution support
- PowerShell-based integration test suite
- Docker support and systemd enablement on distribution start
- Comprehensive testing for various Linux distributions (AlmaLinux, Debian, Fedora, Ubuntu, Kali, openSUSE)
- wsl.conf configuration support

### Features
- Snapshots stored as `.tar` files in `.vagrant/machines/{name}/wsl2/snapshots/`
- Complete distribution state preservation and restoration
- Snapshot management through Vagrant provider capabilities
- Direct command execution via `vagrant ssh -c` with proper output streaming
- Automated integration tests for basic functionality and snapshots
- Docker-in-WSL2 workflows with systemd support

## [0.1.0] - 2025-09-30

### Added
- Initial release of Vagrant WSL2 provider
- Basic WSL2 distribution creation and management
- Integration with Vagrant's standard workflow
- Support for Windows 10/11 with WSL2
- Support for shell, file, and Ansible provisioners
- Distribution compatibility documentation in README

### Features
- Create and destroy WSL2 distributions
- Start, stop, and SSH into distributions
- Vagrant box integration
- Basic provisioning support

### Known Issues
- Per-distribution CPU/memory limits not supported (WSL2 limitation)
- Legacy WSL distributions (Ubuntu-20.04, Ubuntu-22.04, Oracle Linux) require interactive setup
- Some SUSE Enterprise distributions have guest detection issues
- AlmaLinux-10 and archlinux have provisioning limitations

[unreleased]: https://github.com/LeeShan87/vagrant-wsl2-provider/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/LeeShan87/vagrant-wsl2-provider/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/LeeShan87/vagrant-wsl2-provider/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/LeeShan87/vagrant-wsl2-provider/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/LeeShan87/vagrant-wsl2-provider/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/LeeShan87/vagrant-wsl2-provider/releases/tag/v0.1.0
