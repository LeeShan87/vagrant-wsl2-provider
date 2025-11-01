# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Persistent data disk support with VHD/VHDX formats
- Multiple data disk support per VM
- Automatic VHD/VHDX creation using PowerShell New-VHD
- Support for both VHD (VirtualBox-compatible) and VHDX formats
- Data disk mounting using `wsl --mount --vhd`
- Automatic unmounting on VM destroy to prevent file locks
- Integration test for data disk functionality
- Example configuration in `examples/data-disk/`

### Features
- Configure data disks using `data_disk` block in Vagrantfile
- Create new VHD/VHDX files with specified size
- Attach existing VHD/VHDX files from other providers (e.g., VirtualBox)
- Data persists across `vagrant destroy` and `vagrant up` cycles
- Automatic partitioning, formatting, and mounting via provisioning
- Support for custom disk paths and formats

### Configuration
```ruby
wsl.data_disk do |disk|
  disk.size = 100        # Size in GB (for new disks)
  disk.format = 'vhdx'   # 'vhd' or 'vhdx'
  disk.path = 'path'     # Optional: use existing disk
end
```

### Requirements
- **Administrator privileges required**: VHD creation (`New-VHD`) and WSL disk mounting (`wsl --mount`) require running Vagrant as Administrator
- Windows 10 Build 20211+ or Windows 11 for `wsl --mount --vhd` support

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

[unreleased]: https://github.com/LeeShan87/vagrant-wsl2-provider/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/LeeShan87/vagrant-wsl2-provider/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/LeeShan87/vagrant-wsl2-provider/releases/tag/v0.1.0
