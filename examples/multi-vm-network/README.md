# Multi-VM Network Example

This example demonstrates private networking between multiple WSL2 VMs using static IP addresses.

## Configuration

Two VMs are configured with static IPs on the same private network:

- **vm1**: 192.168.50.10 (Ubuntu)
- **vm2**: 192.168.50.11 (Debian)

## WSL2 Networking Architecture Limitations

**IMPORTANT**: WSL2 has a unique networking architecture that differs from traditional hypervisors like VirtualBox or VMware.

### How WSL2 Networking Works

- **Single Shared VM**: All WSL2 distributions run on a **single Hyper-V utility VM**
- **Shared Base IP**: All distributions share the **same base IP address** (e.g., 172.26.143.58)
- **Separate Network Namespaces**: Each distribution has its own network namespace and process isolation
- **Static IPs on eth0**: Each distribution can add additional static IPs to its eth0 interface

### What This Means for Multi-VM Networking

**VM-to-VM Communication**: ✅ **WORKS**
- VMs can communicate with each other using static IPs (192.168.50.10 ↔ 192.168.50.11)
- Each VM has its own network namespace with the assigned static IP

**Windows Host Access**: ❌ **LIMITED**
- Windows host cannot distinguish between VMs using static IPs alone
- All VMs share the same WSL base IP (172.26.143.58)
- Use port forwarding for host-to-VM access on different ports

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

## Process Isolation

Even though VMs share the same base IP, they are **completely isolated** at the process level:

```bash
# On vm1
vagrant ssh vm1
ps aux  # Shows only vm1 processes

# On vm2
vagrant ssh vm2
ps aux  # Shows only vm2 processes (different PIDs, different services)
```

Each distribution runs in its own **network namespace** and **PID namespace**, providing full isolation despite sharing the underlying WSL2 VM.

## Key Takeaways

1. **Private networks work for VM-to-VM communication** - Use static IPs for inter-VM connectivity
2. **Windows host sees one shared IP** - Use port forwarding for host-to-VM access
3. **Process isolation is maintained** - Each distribution is completely isolated despite sharing infrastructure
4. **This is a WSL2 architectural limitation** - Not a bug, this is how WSL2 is designed

## Alternative: Port Forwarding

For Windows host access to specific VMs, use port forwarding instead:

```ruby
config.vm.define "web" do |web|
  web.vm.network "forwarded_port", guest: 80, host: 8080
end

config.vm.define "api" do |api|
  api.vm.network "forwarded_port", guest: 80, host: 8081
end
```

Now Windows can access:
- `http://localhost:8080` → web VM
- `http://localhost:8081` → api VM
