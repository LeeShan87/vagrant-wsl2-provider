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

## Contributing

Bug reports and pull requests are welcome on GitHub.

## License

The gem is available as open source under the [MIT License](./LICENSE).