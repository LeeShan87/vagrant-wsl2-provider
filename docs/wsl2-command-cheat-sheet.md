# WSL2 Command Cheat Sheet

A quick reference guide for WSL2 commands useful when working with the Vagrant WSL2 Provider.

## Distribution Management

### List Distributions
```powershell
# List all WSL distributions with their state and version
wsl -l -v

# List only running distributions
wsl -l --running

# List only distribution names (plain text)
wsl -l -q
```

### Import/Export Distributions
```powershell
# Import a distribution from a tar file
wsl --import <DistributionName> <InstallLocation> <TarFilePath>

# Export a distribution to a tar file
wsl --export <DistributionName> <TarFilePath>

# Example: Import Ubuntu
wsl --import MyUbuntu D:\WSL\MyUbuntu ubuntu-22.04.tar
```

### Remove Distributions
```powershell
# Unregister a distribution (deletes it completely)
wsl --unregister <DistributionName>

# Unregister all vagrant-* distributions (cleanup script)
wsl -l | Select-String -Pattern '\S' | ForEach-Object { $name = $_.Line -replace '\*', '' -replace '\s*\(.*\)', '' -replace '\0', ''; if ($name.Trim() -like 'vagrant-*') { wsl --unregister $name.Trim() } }
```

## Distribution Control

### Start/Stop Distributions
```powershell
# Terminate (stop) a specific distribution
wsl --terminate <DistributionName>

# Terminate all running WSL distributions
wsl --shutdown

# Start a distribution (launch default shell)
wsl -d <DistributionName>
```

### Execute Commands
```powershell
# Execute a command in a distribution
wsl -d <DistributionName> -- <command>

# Example: Check Ubuntu version
wsl -d Ubuntu-22.04 -- cat /etc/os-release

# Execute as specific user
wsl -d <DistributionName> -u <username> -- <command>

# Example: Run as root
wsl -d Ubuntu-22.04 -u root -- apt update

# Example: Start a python webserver in background
wsl -d vagrant-wsl2-basic -u vagrant -- sh -ic "python3 -m http.server 8888 > /dev/null 2>&1 &"

wsl -d vagrant-wsl2-basic -u vagrant --exec bash -ic "nohup python3 -m http.server 8889 > /dev/null 2>&1 &"
```

## Configuration

### Set WSL Version
```powershell
# Set a distribution to WSL2
wsl --set-version <DistributionName> 2

# Set default WSL version for new distributions
wsl --set-default-version 2

# Set a distribution to WSL1
wsl --set-version <DistributionName> 1
```

### Default Distribution
```powershell
# Set default distribution
wsl --set-default <DistributionName>

# Check which is default (marked with *)
wsl -l
```

## File System Access

### Access Windows Files from WSL
```bash
# Windows drives mounted at /mnt/
cd /mnt/c/Users/YourName/Documents
```

### Access WSL Files from Windows
```powershell
# Via network path
\\wsl$\<DistributionName>\home\username

# Example: Open Ubuntu home in Explorer
explorer.exe \\wsl$\Ubuntu-22.04\home\vagrant

# Via wsl command with path conversion
wsl -d <DistributionName> wslpath -w /home/username
```

## Status and Information

### Check Distribution Status
```powershell
# Get status of all distributions
wsl -l -v

# Check if specific distribution exists
wsl -l -q | Select-String "^DistributionName$"

# Get default distribution
wsl -l | Select-String '\(Default\)'
```

### System Information
```powershell
# WSL version
wsl --version

# Kernel version
wsl -- uname -r

# Check WSL status
wsl --status
```

## Networking

### IP Addresses
```powershell
# Get WSL2 VM IP address
wsl hostname -I

# Get Windows host IP from WSL
wsl -- ip route show | grep -i default | awk '{print $3}'

# Show all network interfaces in WSL
wsl ip addr
```

### Port Forwarding
```powershell
# List port forwarding rules
netsh interface portproxy show all

# Add port forward from Windows to WSL
netsh interface portproxy add v4tov4 listenport=<WindowsPort> listenaddress=0.0.0.0 connectport=<WSLPort> connectaddress=<WSL_IP>

# Remove port forward
netsh interface portproxy delete v4tov4 listenport=<WindowsPort> listenaddress=0.0.0.0
```

## Advanced Operations

### Virtual Hard Disk (VHD) Management
```powershell
# Mount a VHD in WSL2
wsl --mount <VHDPath>

# Unmount a VHD
wsl --unmount <VHDPath>

# Compact a WSL2 VHD (must shutdown first)
wsl --shutdown
Optimize-VHD -Path <VHDPath> -Mode Full
```

### Update WSL
```powershell
# Update WSL to latest version
wsl --update

# Check for updates
wsl --update --check

# Rollback to previous version
wsl --update --rollback
```

## Troubleshooting

### Reset and Repair
```powershell
# Check WSL installation
wsl --status

# Reset a distribution (via Windows Settings)
# Settings > Apps > Apps & features > [Distribution] > Advanced options > Reset

# Reinstall WSL kernel
wsl --update --web-download
```

### Common Issues
```powershell
# Fix "reference assembly" error - terminate all WSL
wsl --shutdown

# Clear DNS cache in WSL
wsl -d <DistributionName> -- sudo rm /etc/resolv.conf
wsl --shutdown

# Check Windows features
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
```

## Vagrant WSL2 Provider Specific

### Cleanup Vagrant Distributions
```powershell
# Remove all vagrant-wsl2-* distributions
wsl -l | Select-String -Pattern '\S' | ForEach-Object {
    $name = $_.Line -replace '\*', '' -replace '\s*\(.*\)', '' -replace '\0', ''
    if ($name.Trim() -like 'vagrant-*') {
        wsl --unregister $name.Trim()
    }
}
```

### Check Distribution State
```powershell
# Check if distribution is running
$distro = "vagrant-wsl2-test"
$state = (wsl -l -v | Out-String) -replace '\0', '' | Select-String $distro
if ($state -match 'Running') {
    Write-Host "Distribution is running"
}
```

### Force Remove Stuck Distribution
```powershell
# If wsl --unregister fails, terminate first
wsl --terminate <DistributionName>
Start-Sleep -Seconds 2
wsl --unregister <DistributionName>
```

## Useful PowerShell Helpers

### Clean WSL Output
```powershell
# Remove null characters from wsl output
(wsl -l -v | Out-String) -replace '\0', ''

# Parse WSL list output
wsl -l -v | Out-String | ForEach-Object {
    $_.Trim() -replace '\s+', ','
} | ConvertFrom-Csv -Header Name,State,Version
```

### Check if WSL2 is Available
```powershell
# Check if WSL is installed
Get-Command wsl -ErrorAction SilentlyContinue

# Check if WSL2 is supported
wsl --status | Select-String "WSL version"
```

## References

- [Official WSL Documentation](https://docs.microsoft.com/en-us/windows/wsl/)
- [WSL Command Reference](https://docs.microsoft.com/en-us/windows/wsl/basic-commands)
- [Vagrant WSL2 Provider README](../README.md)
