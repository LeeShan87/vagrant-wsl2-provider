# Init Example

This example demonstrates using `vagrant init` to create a new Vagrantfile with the WSL2 provider.

## Usage

```bash
# Initialize with Ubuntu box
vagrant init Ubuntu

# Bring up the VM
vagrant up --provider=wsl2

# SSH into the VM
vagrant ssh

# Destroy the VM
vagrant destroy -f
```

This creates a basic Vagrantfile that uses the Ubuntu box from Microsoft Store.