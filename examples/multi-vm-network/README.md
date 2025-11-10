# Multi-VM Networking Example

This example demonstrates how to configure multiple WSL2 VMs with static IP addresses for inter-VM communication.

## What This Does

- Creates 2 VMs (Ubuntu and Debian) with static IPs
- Configures private networking: `192.168.50.10` and `192.168.50.11`
- Enables VM-to-VM ping and TCP communication
- Demonstrates networking across different Linux distributions

## Configuration

### Default VMs (auto-start)
- **vm1**: 192.168.50.10 (Ubuntu)
- **vm2**: 192.168.50.11 (Debian)

### Optional VMs (manual start)
- **vm3**: 192.168.50.12 (AlmaLinux-9)
- **vm4**: 192.168.50.13 (FedoraLinux-42)
- **vm5**: 192.168.50.14 (kali-linux)
- **vm6**: 192.168.50.15 (openSUSE-Tumbleweed)

## Usage

```bash
# Start both default VMs
vagrant up

# Start specific VM
vagrant up vm1
vagrant up vm2

# Start optional VMs
vagrant up vm3
vagrant up vm4

# Check IP configuration
vagrant ssh vm1 -c "ip addr show eth0"
vagrant ssh vm2 -c "ip addr show eth0"
```

## WSL2 Networking Limitations

⚠️ **Important:** Private network support in WSL2 is experimental and has significant limitations:

### Shared Network Infrastructure
- **All WSL2 VMs share the same virtual network switch** - There is no true network isolation
- **Same MAC address** - Every VM gets the same MAC on each WSL restart
- **Shared base IP** - All VMs share the same WSL2 DHCP IP (e.g., 172.26.143.58)
- **IP visibility** - You may see other VMs' static IPs when running `ip addr show` on a single VM

### How WSL2 Networking Works

**Single Shared VM**: All WSL2 distributions run on a **single Hyper-V utility VM**
- **Shared Base IP**: All distributions share the **same base IP address** (e.g., 172.26.143.58)
- **Separate Network Namespaces**: Each distribution has its own network namespace and process isolation
- **Static IPs on eth0**: Each distribution can add additional static IPs to its eth0 interface

### What This Means for Multi-VM Networking

**VM-to-VM Communication**: ⚠️ **LIMITED**
- VMs share the same physical NIC and MAC address
- Ping between VMs using static IPs **does not work reliably** (same NIC limitation)
- TCP/UDP application traffic **may work** if routing is configured correctly
- Each VM has its own network namespace, but underlying NIC is shared

**Windows Host Access**: ❌ **LIMITED**
- Windows host cannot distinguish between VMs using static IPs alone
- All VMs share the same WSL base IP (172.26.143.58)
- Use port forwarding for host-to-VM access on different ports

**Process Isolation**: ✅ **WORKS**
- Each distribution runs in its own PID namespace
- `ps aux` shows only processes for that specific VM
- Filesystems are completely isolated

### How Static IPs Are Implemented

The provider uses a **systemd oneshot service** (`vagrant-static-ip.service`) to:
1. Add static IPs to eth0 alongside the WSL2 DHCP IP
2. Preserve WSL2's DNS and routing configuration
3. Automatically restore IPs on VM restart

This approach works across all distributions:
- **Ubuntu**: Uses systemd service (not netplan)
- **Debian**: Uses systemd service (not systemd-networkd config)
- **Fedora/AlmaLinux/Kali**: Uses systemd service (not NetworkManager)
- **openSUSE**: Uses systemd service (not wicked)

**Why not use native network configuration tools?**
- Running `netplan apply` or `systemd-networkd restart` breaks WSL2's DNS
- NetworkManager fails with WSL2's changing MAC addresses
- This systemd service approach is WSL2-friendly and distro-agnostic

## When to Use This

✅ **Good for:**
- Development and testing multi-VM setups
- Learning distributed system concepts
- Quick prototyping of networked applications
- Demonstrating multi-service architectures locally

❌ **Not suitable for:**
- **ANY production deployments** (WSL2 is a development tool, not a server platform)
- Security-sensitive applications requiring isolation
- Scenarios needing true network segmentation
- High-performance networking
- Reliable VM-to-VM communication (ping doesn't work between VMs)

## Testing VM-to-VM Communication

### Start HTTP server on vm1

```bash
vagrant ssh vm1
sudo python3 -m http.server 80 --bind 192.168.50.10
```

### Access from vm2

```bash
vagrant ssh vm2
curl 192.168.50.10
# Should successfully connect to vm1's HTTP server
```

### Check IP Configuration

```bash
vagrant ssh vm1
ip addr show eth0
# You'll see both the shared WSL IP (172.26.143.58) and the static IP (192.168.50.10)
```

## Port Forwarding vs Static IPs

These are **two different features** for different use cases:

**Port Forwarding** (`forwarded_port`):
- Windows host → VM access
- Example: Access web server running in VM from Windows browser
- Use when: You need to access services from Windows

**Static IPs** (`private_network`):
- VM → VM communication
- Example: Web server VM connects to database VM
- Use when: Multiple VMs need to talk to each other

**They are complementary**, not alternatives! You can use both in the same Vagrantfile.

## Troubleshooting

### Static IP not persisting after provision
The systemd service should handle this automatically. Verify:
```bash
vagrant ssh vm1 -c "systemctl status vagrant-static-ip.service"
```

### DNS not working
WSL2 manages DNS automatically. Check:
```bash
vagrant ssh vm1 -c "cat /etc/resolv.conf"
```

### VMs can't ping each other
Ensure both VMs are running and have their static IPs:
```bash
vagrant status
vagrant ssh vm1 -c "ip addr show eth0 | grep inet"
vagrant ssh vm2 -c "ip addr show eth0 | grep inet"
```

### Seeing other VMs' IPs on eth0
This is expected due to WSL2's shared virtual switch. As long as your target IP is present, networking will work correctly.

## Testing

Run the integration test:
```bash
rake test_multi_vm_network
```

This test verifies:
- Both VMs start successfully
- Static IPs are configured correctly
- VMs can ping each other
- Hostname and filesystem isolation
- DNS functionality
- TCP communication between VMs

## Key Takeaways

1. **Static IPs enable VM-to-VM communication** - The only way for VMs to talk to each other in WSL2
2. **Ping between VMs doesn't work** - Same physical NIC limitation, but TCP/UDP apps may work
3. **Process isolation is maintained** - Each distribution is completely isolated despite sharing infrastructure
4. **This is a WSL2 architectural limitation** - Not a bug, this is how WSL2 is designed
5. **WSL2 is for development only** - Never use for production workloads
6. **Static IPs are "best effort"** - They work within WSL2's limitations, but not perfect
