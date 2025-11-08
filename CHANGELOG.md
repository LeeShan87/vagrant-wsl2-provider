# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Private network support with static IP configuration
- Port forwarding support via Windows netsh portproxy
- Multi-distribution network configuration (Ubuntu netplan + Debian systemd-networkd)
- Administrator privilege checking for network operations
- Windows routing setup for static IP access between VMs
- Network configuration examples in `examples/networking/`
- Multi-VM network example with detailed README in `examples/multi-vm-network/`
- Integration test for networking functionality (requires admin privileges)

### Features
- Configure static IPs using `config.vm.network "private_network", ip: "192.168.33.10"`
- Port forwarding using `config.vm.network "forwarded_port", guest: 80, host: 8080`
- Automatic detection of netplan (Ubuntu) vs systemd-networkd (Debian/others)
- Persistent network configuration across VM restarts
- VM-to-VM communication via static IP addresses
- Windows host access to VMs via port forwarding
- Clear warnings when administrator privileges are missing
- Public network (bridged mode) warning - not supported due to WSL2 architecture

### Configuration
```ruby
# Static IP for inter-VM communication
config.vm.network "private_network", ip: "192.168.33.10"

# Port forwarding for Windows host access
config.vm.network "forwarded_port", guest: 80, host: 8080
config.vm.network "forwarded_port", guest: 443, host: 8443, host_ip: "127.0.0.1"
```

### WSL2 Networking Limitations
- **Administrator privileges required**: Network configuration (routes, port forwarding) requires running Vagrant as Administrator
- **Shared base IP**: All WSL2 distributions share the same underlying IP address due to single Hyper-V VM architecture
- **Static IPs for inter-VM only**: Static IPs work for VM-to-VM communication but not for individual Windows host access
- **Port forwarding for host access**: Use port forwarding to access VMs from Windows host
- **Public network not supported**: Bridged networking unavailable due to WSL2's shared virtual switch

### Technical Details
- Network configuration written to `/etc/netplan/60-vagrant.yaml` (Ubuntu) or `/etc/systemd/network/10-eth0.network` (Debian)
- Windows routes created using `route add` for static IP routing
- Port forwarding configured using `netsh interface portproxy`
- Routes and port forwards are non-persistent (removed on Windows restart)
- Re-applied automatically on each `vagrant up`

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

[unreleased]: https://github.com/LeeShan87/vagrant-wsl2-provider/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/LeeShan87/vagrant-wsl2-provider/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/LeeShan87/vagrant-wsl2-provider/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/LeeShan87/vagrant-wsl2-provider/releases/tag/v0.1.0
