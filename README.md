# Vagrant WSL2 Provider

A Vagrant provider plugin for managing WSL2 distributions on Windows.

## Features

- Create and manage WSL2 distributions through Vagrant
- Support for WSL2 configuration (memory, CPU, version)
- Integration with Vagrant's standard workflow
- Cross-platform compatible (Windows-focused)

## Installation

Install the plugin using:

```bash
vagrant plugin install vagrant-wsl2-provider
```

Or install from source:

```bash
git clone https://github.com/LeeShan87/vagrant-wsl2-provider.git
cd vagrant-wsl2-provider
gem build vagrant-wsl2-provider.gemspec
vagrant plugin install vagrant-wsl2-provider-0.1.0.gem
```

## Usage

Create a `Vagrantfile` with the WSL2 provider:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"  # Or any WSL2-compatible box

  config.vm.provider "wsl2" do |wsl|
    wsl.distribution_name = "my-dev-env"
    wsl.version = 2
    wsl.memory = 4096
    wsl.cpus = 2
    wsl.gui_support = true
  end
end
```

Then run:

```bash
vagrant up --provider=wsl2
```

## Configuration

### Provider Options

- `distribution_name`: Name of the WSL2 distribution (default: auto-generated)
- `version`: WSL version (1 or 2, default: 2)
- `memory`: Memory limit in MB (default: 4096)
- `cpus`: Number of CPUs (default: 2)
- `gui_support`: Enable WSLg GUI support (default: false)

## Requirements

- Windows 10/11 with WSL2 enabled
- Vagrant 2.2+
- WSL2 kernel installed

## Development

After checking out the repo, run:

```bash
bundle install
rake spec  # Run tests
```

### Development with Live Reload

For active development, you can create junction points to your working directory so changes are immediately reflected without reinstalling the plugin:

```cmd
# First, install the plugin once
gem build vagrant-wsl2-provider.gemspec
vagrant plugin install vagrant-wsl2-provider-0.1.0.gem

# Remove the installed lib and locales directories
rmdir "C:\Users\YourUsername\.vagrant.d\gems\3.1.3\gems\vagrant-wsl2-provider-0.1.0\lib"
rmdir "C:\Users\YourUsername\.vagrant.d\gems\3.1.3\gems\vagrant-wsl2-provider-0.1.0\locales"

# Create junction points to your development directories (no admin rights required)
mklink /J "C:\Users\YourUsername\.vagrant.d\gems\3.1.3\gems\vagrant-wsl2-provider-0.1.0\lib" "D:\Code\Github\vagrant-wsl2-provider\lib"
mklink /J "C:\Users\YourUsername\.vagrant.d\gems\3.1.3\gems\vagrant-wsl2-provider-0.1.0\locales" "D:\Code\Github\vagrant-wsl2-provider\locales"
```

Now any changes to `lib/` or `locales/` in your working directory are immediately visible to Vagrant without reinstalling.

### Cleanup Helper Commands

Clean up all WSL distributions (useful for testing):

```powershell
wsl -l | Select-String -Pattern '\S' | ForEach-Object { $name = $_.Line -replace '\*', '' -replace '\s*\(.*\)', '' -replace '\0', ''; if ($name.Trim()) { wsl --unregister $name.Trim() } }
```

**Warning:** This removes ALL WSL distributions on your system. Use with caution!

## Known Issues

### Legacy WSL Distributions

Some WSL distributions use the legacy registration system and are not fully supported:

**Affected distributions:**
- Ubuntu-20.04, Ubuntu-22.04
- OracleLinux_7_9, OracleLinux_8_10, OracleLinux_9_5

**Issues:**
- `--no-launch` flag does not properly register the distribution
- Distributions require interactive setup (username/password prompt)
- Provider cannot detect distribution after installation

### SUSE Enterprise Distributions

SUSE Linux Enterprise distributions may have guest detection issues:
- SUSE-Linux-Enterprise-15-SP6
- SUSE-Linux-Enterprise-15-SP7

### Bleeding Edge Distributions

Very recent distributions may have provisioning issues:
- AlmaLinux-10, AlmaLinux-Kitten-10 (Ansible provisioner fails due to missing EPEL repositories)

### Minimal Distributions

Some distributions have minimal installations without common tools:
- archlinux (missing `sudo` by default - Ansible provisioner fails)

### Tested and Working Distributions

The following distributions are fully tested and working with shell/file/ansible provisioners:
- AlmaLinux-8, AlmaLinux-9
- Debian
- FedoraLinux-42
- Ubuntu, Ubuntu-24.04
- Kali-Linux
- openSUSE-Tumbleweed

## Contributing

Bug reports and pull requests are welcome on GitHub.

## License

The gem is available as open source under the [MIT License](./LICENSE).

## WSL2 Distribution Lifecycle

  **Important:** WSL2 distributions behave differently from traditional VMs!

  ### Automatic Sleep Mode
  - WSL2 distributions automatically enter "stopped" state when no processes are running
  - This is **normal behavior**, not a bug
  - Unlike VMs, WSL2 distributions don't stay "running" idle

  ### Vagrant Status Meanings
  - `stopped` = Distribution exists, no active processes (ready to use)
  - `running` = Distribution has active processes
  - `not created` = Distribution doesn't exist

  ### Typical Workflow
  ```bash
  vagrant up --provider=wsl2     # Creates distribution (shows "stopped")
  vagrant ssh                    # Starts shell (shows "running")
  exit                          # Shell closes (returns to "stopped")
  vagrant status                # Shows "stopped" - this is normal!