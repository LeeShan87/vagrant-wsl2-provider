# Provisioners Examples

This directory contains examples demonstrating different Vagrant provisioners working with the WSL2 provider.

## Available Provisioner Examples

### Shell Provisioner (`shell/`)
Demonstrates using shell scripts for provisioning.
- Inline shell commands
- Running commands as root vs. vagrant user
- Installing packages

```bash
cd shell
vagrant up --provider=wsl2
```

### File Provisioner (`file/`)
Demonstrates uploading files to the WSL2 distribution.
- Upload files from host to guest
- Verify file contents

```bash
cd file
vagrant up --provider=wsl2
```

### Ansible Local Provisioner (`ansible/`)
Demonstrates using Ansible for provisioning.
- Automatic Ansible installation
- Running playbooks
- Installing packages via Ansible

```bash
cd ansible
vagrant up --provider=wsl2
```

### Chef Solo Provisioner (`chef/`)
Demonstrates using Chef Solo for provisioning.
- Chef cookbook execution
- Creating files and directories
- Installing packages

**Known Issue**: Currently fails due to shared folder symlink issues with Chef's cookbooks directory.

```bash
cd chef
vagrant up --provider=wsl2
```

### SaltStack Provisioner (`salt/`)
Demonstrates using SaltStack for provisioning.
- Masterless Salt configuration
- Running Salt states
- Installing packages via Salt

**Known Issue**: Bootstrap script URL has changed. Vagrant 2.4.1 uses an outdated URL. Requires Vagrant 2.4.6+.

```bash
cd salt
vagrant up --provider=wsl2
```

## Testing

All provisioners are tested via the integration test suite:

```bash
rake test_provisioners       # Test shell, file, and ansible provisioners
rake test_provisioners_full  # Test all provisioners including chef and salt
```

By default, only shell, file, and ansible provisioners are tested. Use `test_provisioners_full` to include chef and salt provisioners, which are tagged with "KnownIssue" and may fail until the underlying issues are resolved.
