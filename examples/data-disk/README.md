# Data Disk Example

This example demonstrates how to use persistent data disks with the WSL2 provider.

## What This Example Shows

- Creating multiple data disks (VHD and VHDX formats)
- Automatic partitioning, formatting, and mounting
- Data persistence across VM lifecycle
- Using existing VHD/VHDX files from other providers (e.g., VirtualBox)

## Features

### Multiple Disk Support

The example creates two data disks:
1. **Primary disk**: 10GB VHDX format
2. **Secondary disk**: 5GB VHD format (VirtualBox-compatible)

### Data Persistence

Data disks survive `vagrant destroy` and are automatically reattached on `vagrant up`.

### Formats Supported

- **VHDX**: Windows native format (default)
- **VHD**: Compatible with VirtualBox and older Windows versions

## Usage

### Start the VM

```bash
vagrant up
```

This will:
1. Create the WSL2 distribution
2. Create VHD/VHDX files for data disks (if they don't exist)
3. Mount the data disks using `wsl --mount`
4. Partition, format, and mount the disks inside WSL
5. Set up automatic mounting on boot

### Verify Data Disks

```bash
vagrant ssh
```

Inside the VM:
```bash
# List block devices
lsblk

# Check mounted filesystems
df -h | grep /mnt/data

# View test files
cat /mnt/data1/test.txt
cat /mnt/data2/test.txt
```

### Test Persistence

```bash
# Create a file on data disk
vagrant ssh -c "echo 'My persistent data' > /mnt/data1/myfile.txt"

# Destroy the VM
vagrant destroy -f

# Recreate the VM
vagrant up

# Verify data persisted
vagrant ssh -c "cat /mnt/data1/myfile.txt"
```

### Using Existing VHD/VHDX Files

To use an existing disk from VirtualBox or another source:

```ruby
config.vm.provider "wsl2" do |wsl|
  wsl.data_disk do |disk|
    disk.path = 'D:\\VirtualBox\\my-existing-disk.vhd'
  end
end
```

## Configuration Options

### Create New Disk

```ruby
wsl.data_disk do |disk|
  disk.size = 100        # Size in GB
  disk.format = 'vhdx'   # 'vhd' or 'vhdx'
end
```

### Use Existing Disk

```ruby
wsl.data_disk do |disk|
  disk.path = 'D:\\path\\to\\disk.vhdx'
end
```

## Disk Layout

- `/dev/sda` - System disk (WSL2 distribution)
- `/dev/sdb` - First data disk (mounted at `/mnt/data1`)
- `/dev/sdc` - Second data disk (mounted at `/mnt/data2`)

## Notes

- **Administrator privileges required**: VHD creation and WSL mounting require running Vagrant/PowerShell as Administrator
- Data disks are stored in `.vagrant/machines/default/wsl2/` by default
- Custom paths can be specified using `disk.path`
- Disks are automatically unmounted during `vagrant destroy` to prevent file locks
- Requires Windows 10 Build 20211+ or Windows 11 for `wsl --mount` support

## Cleanup

To completely remove data disks:

```bash
# Destroy the VM
vagrant destroy -f

# Manually delete VHD files
Remove-Item .vagrant\machines\default\wsl2\data-disk-*.vhd*
```

## Integration with VirtualBox

You can convert VirtualBox VDI disks to VHD format and use them with WSL2:

```powershell
# In VirtualBox
VBoxManage clonehd source.vdi target.vhd --format VHD

# Then use in Vagrantfile
wsl.data_disk do |disk|
  disk.path = 'path\\to\\target.vhd'
end
```
