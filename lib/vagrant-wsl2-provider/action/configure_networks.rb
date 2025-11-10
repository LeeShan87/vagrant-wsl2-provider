require "vagrant"

module VagrantPlugins
  module WSL2
    module Action
      class ConfigureNetworks
        def initialize(app, env)
          @app = app
          @env = env
        end

        def call(env)
          @machine = env[:machine]
          @ui = env[:ui]

          # Get network configuration from Vagrantfile
          networks = @machine.config.vm.networks

          if networks.empty?
            @ui.info("No networks configured")
            return @app.call(env)
          end

          # Check for administrator privileges on Windows
          unless has_admin_privileges?
            @ui.warn("Network configuration requires administrator privileges")
            @ui.warn("Please run Vagrant as administrator to configure:")
            @ui.warn("  - Static IP addresses (private_network)")
            @ui.warn("  - Port forwarding (forwarded_port)")
            @ui.warn("Skipping network configuration...")
            return @app.call(env)
          end

          @ui.info("Configuring networks...")

          # Collect all static IPs first for netplan config
          @static_ips = []

          networks.each do |type, options|
            @ui.info("Network type: #{type}")
            @ui.info("Options: #{options.inspect}")

            case type
            when :private_network
              configure_private_network(options)
            when :public_network
              configure_public_network(options)
            when :forwarded_port
              configure_forwarded_port(options)
            else
              @ui.warn("Unsupported network type: #{type}")
            end
          end

          # Write netplan config with all static IPs
          write_netplan_config if @static_ips.any?

          @app.call(env)
        end

        private

        def has_admin_privileges?
          # Check if running with administrator privileges on Windows
          cmd = "([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)"
          result = Vagrant::Util::Subprocess.execute("powershell", "-Command", cmd)

          if result.exit_code == 0 && result.stdout.strip.downcase == "true"
            return true
          end

          false
        rescue
          # If we can't determine, assume we don't have admin rights
          false
        end

        def configure_private_network(options)
          if options[:ip]
            @ui.info("Configuring private network with IP: #{options[:ip]}")
            configure_static_ip(options[:ip], options[:netmask] || "255.255.255.0")
          else
            @ui.info("Configuring private network with DHCP")
            # WSL2 uses DHCP by default, nothing to do
          end
        end

        def configure_static_ip(ip, netmask)
          # Calculate network prefix (CIDR)
          prefix = netmask_to_prefix(netmask)

          # Configure using ip command for immediate effect
          @machine.communicate.sudo("ip addr add #{ip}/#{prefix} dev eth0 || true")

          # Add to list for netplan config (written later with all IPs)
          @static_ips << { ip: ip, prefix: prefix }

          # Get the WSL2 VM's main IP address (the one Windows can reach)
          wsl_ip = get_wsl_ip_address

          if wsl_ip
            # Set up Windows routing for static IP
            setup_windows_routing(ip, wsl_ip)
          end

          @ui.info("Static IP #{ip} configured successfully")
        end

        def write_netplan_config
          # Universal solution for all distros - systemd service
          # No need to detect distro or network manager, network-online.target works everywhere
          write_systemd_static_ip_service
        end

        def write_systemd_static_ip_service
          # Universal method for creating a systemd service to manage static IPs
          # Works for all distros (Ubuntu/Debian/Fedora/AlmaLinux/Kali/openSUSE)
          #
          # Why systemd service instead of native network config?
          # - WSL2 manages eth0 with DHCP for DNS and default route
          # - Applying network configs (netplan apply, systemd-networkd restart, nmcli)
          #   causes loss of WSL2 DHCP IP which breaks DNS/routing
          # - MAC address changes on WSL restart break NetworkManager configs
          # - This service adds static IPs without disturbing WSL2's network management

          ip_commands = @static_ips.map { |ip_info|
            "ip addr add #{ip_info[:ip]}/#{ip_info[:prefix]} dev eth0 || true"
          }.join("\n")

          service_config = <<~SERVICE
            [Unit]
            Description=Vagrant Static IP Configuration
            After=network-online.target
            Wants=network-online.target

            [Service]
            Type=oneshot
            RemainAfterExit=yes
            ExecStart=/bin/bash -c '#{ip_commands}'

            [Install]
            WantedBy=multi-user.target
          SERVICE

          service_path = "/tmp/vagrant-static-ip.service"

          escaped_config = service_config.gsub("'", "'\\\\''")
          @machine.communicate.execute("echo '#{escaped_config}' > #{service_path}")

          @machine.communicate.sudo("mkdir -p /etc/systemd/system")
          @machine.communicate.sudo("mv #{service_path} /etc/systemd/system/vagrant-static-ip.service")
          @machine.communicate.sudo("chmod 644 /etc/systemd/system/vagrant-static-ip.service")

          @machine.communicate.sudo("systemctl daemon-reload")
          @machine.communicate.sudo("systemctl enable vagrant-static-ip.service 2>/dev/null || true")
          @machine.communicate.sudo("systemctl start vagrant-static-ip.service 2>/dev/null || true")

          @ui.info("Static IP service configured with #{@static_ips.length} IP(s)")
        end

        def get_wsl_ip_address
          # Get the eth0 IP that Windows can already reach
          # Extract IP from WSL (suppress output)
          ip_output = ""
          @machine.communicate.execute("hostname -I", error_check: false) do |type, data|
            ip_output += data if type == :stdout
          end

          # Return the first IP (this is the one WSL uses by default)
          wsl_ip = ip_output.strip.split.first
          wsl_ip
        rescue
          nil
        end

        def setup_windows_routing(static_ip, wsl_ip)
          # Add a Windows route to forward traffic from static IP to WSL VM IP
          # This is non-persistent (removed on Windows restart)
          @ui.info("Setting up Windows route for static IP: #{static_ip}")

          add_windows_route(static_ip, wsl_ip)
        end

        def add_windows_route(static_ip, wsl_ip)
          # Add route: route add <static_ip> mask 255.255.255.255 <wsl_ip>
          # Use /32 mask (255.255.255.255) for host-specific route
          cmd = "route add #{static_ip} mask 255.255.255.255 #{wsl_ip}"
          result = Vagrant::Util::Subprocess.execute("powershell", "-Command", cmd)

          if result.exit_code == 0
            @ui.info("Windows route added: #{static_ip} -> #{wsl_ip}")
          elsif result.stderr.to_s.include?("already exists") || result.stdout.to_s.include?("already exists")
            @ui.info("Route already exists for #{static_ip}")
          else
            @ui.warn("Failed to add Windows route. Exit code: #{result.exit_code}")
            @ui.warn("STDOUT: #{result.stdout}") unless result.stdout.empty?
            @ui.warn("STDERR: #{result.stderr}") unless result.stderr.empty?
            @ui.warn("Note: This operation requires administrator privileges")
          end
        end

        def netmask_to_prefix(netmask)
          # Convert netmask to CIDR prefix
          # 255.255.255.0 -> 24
          octets = netmask.split('.').map(&:to_i)
          binary = octets.map { |o| o.to_s(2).rjust(8, '0') }.join
          binary.count('1')
        end

        def configure_public_network(options)
          @ui.warn("Public network (bridged mode) is not supported on WSL2 provider")
          @ui.warn("WSL2 uses a shared Hyper-V virtual switch that cannot be configured per-distribution")
          @ui.warn("Consider using private_network with static IP or forwarded_port instead")
        end

        def configure_forwarded_port(options)
          guest = options[:guest]
          host = options[:host]
          host_ip = options[:host_ip] || "0.0.0.0"

          @ui.info("Configuring port forward: #{host_ip}:#{host} -> guest:#{guest}")

          # Get WSL IP address
          wsl_ip = get_wsl_ip_address
          return unless wsl_ip

          # Use netsh to set up port forwarding from Windows to WSL
          # This ensures the port forwarding works reliably
          setup_port_forward(host_ip, host, wsl_ip, guest)
        end

        def setup_port_forward(listen_address, listen_port, connect_address, connect_port)
          # Normalize 0.0.0.0 to actual listen address for netsh
          # netsh doesn't accept 0.0.0.0, we need to use actual IP or leave it empty for all interfaces
          if listen_address == "0.0.0.0"
            # Listen on all interfaces - use the actual Windows IP or just omit
            # For simplicity, let's use 127.0.0.1 and the actual adapter IP
            listen_addresses = ["127.0.0.1"]
          else
            listen_addresses = [listen_address]
          end

          listen_addresses.each do |addr|
            # Build netsh command
            cmd = "netsh interface portproxy add v4tov4 listenaddress=#{addr} listenport=#{listen_port} connectaddress=#{connect_address} connectport=#{connect_port}"

            # Execute on Windows host (not in WSL)
            result = Vagrant::Util::Subprocess.execute("powershell", "-Command", cmd)

            if result.exit_code == 0
              @ui.info("Port forward configured: #{addr}:#{listen_port} -> #{connect_address}:#{connect_port}")
            else
              @ui.warn("Failed to configure port forward. Exit code: #{result.exit_code}")
              @ui.warn("STDOUT: #{result.stdout}") unless result.stdout.empty?
              @ui.warn("STDERR: #{result.stderr}") unless result.stderr.empty?
            end
          end
        end
      end
    end
  end
end
