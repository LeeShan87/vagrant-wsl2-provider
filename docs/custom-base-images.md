# Custom Base Images

This guide explains how to create custom base images for the Vagrant WSL2 provider.

## Overview

The Vagrant WSL2 provider uses a caching system to speed up VM creation. When you first run `vagrant up`, the provider:

1. Downloads/installs a clean WSL2 distribution (e.g., Ubuntu-24.04)
2. Exports it to a cache directory: `~/.vagrant.d/wsl2-cache/`
3. Creates project-specific VMs from this cached image

This ensures every `vagrant up` starts with a clean, reproducible environment.

## Why Create Custom Base Images?

You might want to create a custom base image if you:

- Need pre-installed packages in all your VMs (e.g., Docker, specific tools)
- Want to apply custom configurations before VM creation
- Need a specific distribution version not available via `wsl --install`
- Want to optimize VM startup time by pre-installing common dependencies

## Creating a Custom Base Image

### Method 1: Manual Creation (Recommended)

**Step 1: Create and customize a WSL distribution**

```powershell
# Install a fresh distribution
wsl --install Ubuntu-24.04 --no-launch

# Launch it and install your custom packages
wsl -d Ubuntu-24.04

# Inside the distribution:
sudo apt update
sudo apt install -y build-essential git curl
# ... install whatever you need ...

# Exit the distribution
exit
```

**Step 2: Export to cache directory**

```powershell
# Create cache directory if it doesn't exist
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.vagrant.d\wsl2-cache"

# Export your customized distribution
wsl --export Ubuntu-24.04 "$env:USERPROFILE\.vagrant.d\wsl2-cache\Ubuntu-24.04-vagrant-base.tar"
```

**Step 3: Clean up the original (optional)**

```powershell
# Remove the original distribution to save space
wsl --unregister Ubuntu-24.04
```

**Step 4: Use in Vagrantfile**

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "Ubuntu-24.04"

  config.vm.provider "wsl2" do |wsl|
    # Vagrant will use your custom cached image!
  end
end
```

### Method 2: Using an Existing Distribution

If you already have a WSL distribution that you've customized and want to use as a base:

```powershell
# Export your existing distribution to the cache
wsl --export MyCustomDistro "$env:USERPROFILE\.vagrant.d\wsl2-cache\MyCustomDistro-vagrant-base.tar"
```

Then in your Vagrantfile:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "MyCustomDistro"

  config.vm.provider "wsl2" do |wsl|
    # Will use your custom cached image
  end
end
```

## Important Considerations

### Cache Naming Convention

The cache file **must** follow this naming pattern:

```
<distribution-name>-vagrant-base.tar
```

For example:
- `Ubuntu-24.04-vagrant-base.tar` for box name `Ubuntu-24.04`
- `Debian-vagrant-base.tar` for box name `Debian`
- `MyCustomDistro-vagrant-base.tar` for box name `MyCustomDistro`

### Keeping Images Clean

**Best Practice**: Don't include user-specific data or temporary files in your base image.

**What to avoid**:
- User home directory modifications
- Running services or daemons
- Temporary files in `/tmp`
- User-specific SSH keys or credentials
- Project-specific code or data

**What's okay**:
- System-wide package installations
- System configuration files
- Pre-compiled tools or binaries
- System-wide environment variables

### Automatic Backup for Legacy Distributions

If you have a legacy distribution (e.g., Ubuntu-20.04) already installed locally, the provider will automatically:

1. Backup your existing distribution
2. Install a fresh clean version
3. Export it to cache
4. Restore your original distribution

This ensures you don't lose your existing work while still getting a clean cache.

## Cache Location

All cached base images are stored in:

```
Windows: C:\Users\<username>\.vagrant.d\wsl2-cache\
```

You can manually manage these files:

```powershell
# List cached images
Get-ChildItem "$env:USERPROFILE\.vagrant.d\wsl2-cache"

# Remove a specific cache
Remove-Item "$env:USERPROFILE\.vagrant.d\wsl2-cache\Ubuntu-24.04-vagrant-base.tar"

# Remove all caches
Remove-Item "$env:USERPROFILE\.vagrant.d\wsl2-cache\*"
```

## Updating Cache

To update a cached image with new packages or configurations:

1. Delete the existing cache file
2. Run `vagrant up` - the provider will recreate it

OR manually:

```powershell
# Delete old cache
Remove-Item "$env:USERPROFILE\.vagrant.d\wsl2-cache\Ubuntu-24.04-vagrant-base.tar"

# Create new custom image using Method 1 above
# ...
```

## Examples

### Example 1: Docker Pre-installed

```powershell
# Install Ubuntu
wsl --install Ubuntu-24.04 --no-launch
wsl -d Ubuntu-24.04

# Inside Ubuntu, install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
exit

# Export to cache
wsl --export Ubuntu-24.04 "$env:USERPROFILE\.vagrant.d\wsl2-cache\Ubuntu-24.04-vagrant-base.tar"

# Clean up
wsl --unregister Ubuntu-24.04
```

### Example 2: Development Tools Pre-installed

```powershell
wsl --install Debian --no-launch
wsl -d Debian

# Install development tools
sudo apt update
sudo apt install -y build-essential cmake ninja-build git
exit

# Export to cache
wsl --export Debian "$env:USERPROFILE\.vagrant.d\wsl2-cache\Debian-vagrant-base.tar"
wsl --unregister Debian
```

## Troubleshooting

### Cache Not Being Used

If Vagrant isn't using your custom cache:

1. **Check the filename**: Must be `<box-name>-vagrant-base.tar`
2. **Check the location**: Must be in `~/.vagrant.d/wsl2-cache/`
3. **Check the box name**: In Vagrantfile, `config.vm.box` must match the cache filename

### Large Cache Files

If your cache files are very large:

- Avoid including package caches: `sudo apt clean`
- Remove temporary files before export
- Consider using VHDX compression (future feature)

### Permission Issues

If you get permission errors when exporting:

```powershell
# Run PowerShell as Administrator
wsl --export DistroName "path\to\cache.tar"
```

## See Also

- [WSL2 Command Cheat Sheet](wsl2-command-cheat-sheet.md)
- [Vagrant Documentation](https://www.vagrantup.com/docs)
- [WSL Documentation](https://learn.microsoft.com/en-us/windows/wsl/)
