require "vagrant/util/subprocess"
require "fileutils"

module VagrantPlugins
  module WSL2
    class Driver
      def initialize(machine)
        @machine = machine
        @config = machine.provider_config
      end

      # Get the distribution name, preferring machine.id if it exists
      def distribution_name
        @machine.id || @config.distribution_name
      end

      # Get the current state of the WSL2 distribution
      def state
        # Return :not_created if we don't have a distribution name yet
        return :not_created unless distribution_name

        # Use wsl --list --verbose to check state without waking up the distribution
        result = execute_safe("wsl", "--list", "--verbose")
        return :not_created unless result

        distributions = parse_wsl_list_output(result.stdout)
        distro = distributions.find { |d| d[:name] == distribution_name }

        return :not_created unless distro

        case distro[:state]
        when "Running"
          :running
        when "Stopped"
          :stopped
        else
          :unknown
        end
      rescue
        :not_created
      end

      # Create a new WSL2 distribution
      def create(box_path)
        # Ensure the distribution directory exists
        dist_dir = distribution_path
        FileUtils.mkdir_p(dist_dir) unless File.exist?(dist_dir)

        # Import the distribution from a tar.gz file
        execute("wsl", "--import", distribution_name,
                dist_dir, box_path, "--version", @config.version.to_s)
      end

      # Start the WSL2 distribution
      # @param silent [Boolean] If true, suppress UI output
      def start(silent: false)
        @machine.ui.info "Starting WSL2 distribution: #{distribution_name}" unless silent
        execute("wsl", "--distribution", distribution_name, "--exec", "true")
      end

      # Stop the WSL2 distribution
      def halt
        @machine.ui.info "Stopping WSL2 distribution: #{distribution_name}"
        execute("wsl", "--terminate", distribution_name)
      end

      # Destroy the WSL2 distribution
      def destroy
        execute("wsl", "--unregister", distribution_name)

        # Wait a moment for WSL to release file handles
        sleep 1

        # Clean up distribution files with retry logic
        dist_path = distribution_path
        if File.exist?(dist_path)
          retries = 0
          max_retries = 5
          begin
            FileUtils.rm_rf(dist_path)
          rescue Errno::EACCES, Errno::ENOTEMPTY => e
            retries += 1
            if retries < max_retries
              sleep 1
              retry
            else
              @machine.ui.warn "Could not remove distribution directory: #{e.message}"
              @machine.ui.warn "You may need to manually delete: #{dist_path}"
            end
          end
        end
      end

      # Execute a command in the WSL2 distribution
      def execute_in_wsl(*args)
        execute("wsl", "--distribution", distribution_name, *args)
      end

      # Public wrapper for execute method (for use by actions)
      def execute_command(*args)
        execute(*args)
      end

      # Apply wsl.conf configuration to the distribution
      def apply_wsl_conf
        wsl_conf_content = generate_wsl_conf
        return if wsl_conf_content.empty?

        # Write wsl.conf to /etc/wsl.conf in the distribution
        execute_in_wsl("bash", "-c", "cat > /etc/wsl.conf << 'EOF'\n#{wsl_conf_content}\nEOF")

        # Restart the distribution to apply wsl.conf changes
        @machine.ui.info "Restarting distribution to apply wsl.conf changes"
        @machine.ui.warn "This will shutdown ALL WSL2 distributions to apply configuration"

        # Use wsl --shutdown to fully restart WSL2 backend
        # This is required for wsl.conf changes (especially systemd) to take effect
        Vagrant::Util::Subprocess.execute("wsl", "--shutdown")

        # Wait for WSL2 to fully shutdown
        sleep 2

        start
      end

      # Get the path where snapshots should be stored
      def snapshots_path
        path = @machine.data_dir.join("snapshots")
        FileUtils.mkdir_p(path) unless File.exist?(path)
        path.to_s
      end

      # Get the path for a specific snapshot
      def snapshot_path(snapshot_name)
        File.join(snapshots_path, "#{snapshot_name}.tar")
      end

      # List all snapshots
      def list_snapshots
        return [] unless File.exist?(snapshots_path)

        Dir.glob(File.join(snapshots_path, "*.tar")).map do |path|
          File.basename(path, ".tar")
        end.sort
      end

      # Save a snapshot
      def save_snapshot(snapshot_name)
        snapshot_file = snapshot_path(snapshot_name)

        # Export the current distribution to a tar file
        @machine.ui.info "Saving snapshot: #{snapshot_name}"
        execute("wsl", "--export", distribution_name, snapshot_file)

        @machine.ui.success "Snapshot saved: #{snapshot_name}"
      end

      # Restore a snapshot
      def restore_snapshot(snapshot_name)
        snapshot_file = snapshot_path(snapshot_name)

        unless File.exist?(snapshot_file)
          raise Errors::SnapshotNotFound, name: snapshot_name
        end

        @machine.ui.info "Restoring snapshot: #{snapshot_name}"

        # First, unregister the current distribution
        halt if state == :running
        execute("wsl", "--unregister", distribution_name)

        # Import the snapshot as the distribution
        dist_dir = distribution_path
        FileUtils.mkdir_p(dist_dir) unless File.exist?(dist_dir)

        execute("wsl", "--import", distribution_name,
                dist_dir, snapshot_file, "--version", @config.version.to_s)

        @machine.ui.success "Snapshot restored: #{snapshot_name}"
      end

      # Delete a snapshot
      def delete_snapshot(snapshot_name)
        snapshot_file = snapshot_path(snapshot_name)

        unless File.exist?(snapshot_file)
          raise Errors::SnapshotNotFound, name: snapshot_name
        end

        FileUtils.rm(snapshot_file)
        @machine.ui.success "Snapshot deleted: #{snapshot_name}"
      end

      # Data disk management

      # Get the default path for a data disk
      def default_data_disk_path(index, format = 'vhdx')
        @machine.data_dir.join("data-disk-#{index}.#{format}").to_s
      end

      # Create a VHD/VHDX file using PowerShell
      def create_data_disk(path, size_gb, format = 'vhdx')
        return if File.exist?(path)

        @machine.ui.info "Creating #{format.upcase} data disk: #{File.basename(path)} (#{size_gb}GB)"

        size_bytes = size_gb * 1024 * 1024 * 1024

        # Use Windows-style path for PowerShell
        windows_path = path.gsub('/', '\\')

        # Ensure parent directory exists
        parent_dir = File.dirname(path)
        FileUtils.mkdir_p(parent_dir) unless File.exist?(parent_dir)

        # PowerShell command to create VHD/VHDX
        # The format is determined by the file extension (.vhd or .vhdx)
        # Ensure the path has the correct extension
        if !windows_path.downcase.end_with?('.vhd') && !windows_path.downcase.end_with?('.vhdx')
          windows_path += ".#{format.downcase}"
        end

        ps_command = "New-VHD -Path '#{windows_path}' -SizeBytes #{size_bytes} -Dynamic"

        result = Vagrant::Util::Subprocess.execute(
          "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
          "-Command", ps_command
        )

        if result.exit_code != 0
          error_msg = result.stderr
          # Check if it's a permission error
          if error_msg.include?("permission") || error_msg.include?("administrator")
            error_msg += "\n\nAdministrator privileges are required to create VHD files."
            error_msg += "\nPlease run Vagrant/PowerShell as Administrator."
          end

          raise Errors::DataDiskCreateFailed,
                path: path,
                stderr: error_msg
        end

        @machine.ui.success "Data disk created: #{File.basename(path)}"
      end

      # Mount all configured data disks
      def mount_data_disks
        return unless @config.data_disks&.any?

        # Check if data disks are already mounted in the distribution
        if data_disk_already_mounted?(@config.data_disks.count)
          @machine.ui.info "Data disks already mounted (#{@config.data_disks.count} disks found)"
          return
        end

        @machine.ui.info "Mounting data disks..."

        @config.data_disks.each_with_index do |disk_config, index|
          format = disk_config.format || 'vhdx'

          # Determine VHD path
          vhd_path = disk_config.path || default_data_disk_path(index, format)

          # Create VHD if it doesn't exist and size is specified
          if !File.exist?(vhd_path) && disk_config.size
            create_data_disk(vhd_path, disk_config.size, format)
          end

          # Mount the VHD
          mount_data_disk(vhd_path, index)
        end
      end

      # Check if data disk is already accessible in the distribution
      def data_disk_already_mounted?(expected_disk_count)
        return false unless state == :running

        # Count block devices that could be data disks (sde and later)
        # Use wsl -d to run command inside the distribution
        result = Vagrant::Util::Subprocess.execute(
          "wsl", "-d", distribution_name, "--", "lsblk", "-nd", "-o", "NAME"
        )
        return false if result.exit_code != 0

        # Count devices sde and later
        device_count = result.stdout.lines.count { |line| line.match?(/^sd[e-z]$/) }

        # If we have at least as many devices as expected, disks are already mounted
        device_count >= expected_disk_count
      end

      # Mount a single data disk
      def mount_data_disk(vhd_path, index)
        unless File.exist?(vhd_path)
          raise Errors::DataDiskNotFound, path: vhd_path
        end

        @machine.ui.info "Mounting data disk: #{File.basename(vhd_path)}"

        # Use Windows-style path for wsl command
        windows_path = vhd_path.gsub('/', '\\')

        # Mount the VHD using wsl --mount
        # --bare: Don't mount to a specific path automatically
        result = Vagrant::Util::Subprocess.execute(
          "wsl", "--mount", "--vhd", windows_path, "--bare"
        )

        # Note: exit code 0 means success
        # If already mounted, wsl returns an error but we can ignore it
        if result.exit_code != 0
          error_msg = result.stderr

          # Check if already mounted (this is not a fatal error)
          if error_msg.include?("already") || error_msg.include?("attached")
            @machine.ui.warn "Data disk already mounted: #{File.basename(vhd_path)}"
          else
            # Check if it's a permission error
            if error_msg.empty? || error_msg.include?("access") || error_msg.include?("permission") || error_msg.include?("administrator")
              error_msg = "Failed to mount VHD. Administrator privileges are required.\n"
              error_msg += "Please run Vagrant/PowerShell as Administrator to use data disk features.\n"
              error_msg += "Original error: #{result.stderr}" unless result.stderr.empty?
            end

            raise Errors::DataDiskMountFailed,
                  path: vhd_path,
                  stderr: error_msg
          end
        else
          @machine.ui.success "Data disk mounted: #{File.basename(vhd_path)}"
        end
      end

      # Unmount all configured data disks
      def unmount_data_disks
        return unless @config.data_disks&.any?

        @machine.ui.info "Unmounting data disks..."

        @config.data_disks.each_with_index do |disk_config, index|
          format = disk_config.format || 'vhdx'
          vhd_path = disk_config.path || default_data_disk_path(index, format)
          unmount_data_disk(vhd_path) if File.exist?(vhd_path)
        end
      end

      # Unmount a single data disk
      def unmount_data_disk(vhd_path)
        @machine.ui.info "Unmounting data disk: #{File.basename(vhd_path)}"

        # Use Windows-style path for wsl command
        windows_path = vhd_path.gsub('/', '\\')

        result = Vagrant::Util::Subprocess.execute(
          "wsl", "--unmount", windows_path
        )

        if result.exit_code != 0
          # Check if not mounted (this is not a fatal error)
          if result.stderr.include?("not") || result.stderr.include?("attached")
            @machine.ui.warn "Data disk not mounted: #{File.basename(vhd_path)}"
          else
            raise Errors::DataDiskUnmountFailed,
                  path: vhd_path,
                  stderr: result.stderr
          end
        else
          @machine.ui.success "Data disk unmounted: #{File.basename(vhd_path)}"
        end
      end

      private

      # Generate wsl.conf content from configuration
      def generate_wsl_conf
        config_hash = @config.wsl_conf.to_h
        return "" if config_hash.empty?

        content = []

        config_hash.each do |section, values|
          next if values.nil? || values.empty?

          content << "[#{section}]"
          values.each do |key, value|
            next if value.nil?
            content << "#{key}=#{value}"
          end
          content << ""
        end

        content.join("\n")
      end

      # Execute a Windows command
      def execute(*args)
        result = Vagrant::Util::Subprocess.execute(*args)

        if result.exit_code != 0
          # Include both stdout and stderr in error message
          error_output = ""
          error_output += result.stdout.strip unless result.stdout.nil? || result.stdout.strip.empty?
          error_output += "\n" unless error_output.empty? || result.stderr.nil? || result.stderr.strip.empty?
          error_output += result.stderr.strip unless result.stderr.nil? || result.stderr.strip.empty?

          raise Errors::WSLCommandFailed,
                command: args.join(" "),
                stderr: error_output
        end

        result
      end

      # Execute a WSL command safely, returning nil if no distributions exist
      def execute_safe(*args)
        result = Vagrant::Util::Subprocess.execute(*args)

        if result.exit_code != 0
          # Check if error is about no distributions installed (exit code based)
          # WSL returns specific exit codes when no distributions are installed
          if result.exit_code == 1 || result.exit_code == 4294967295
            return nil
          end

          raise Errors::WSLCommandFailed,
                command: args.join(" "),
                stderr: result.stderr
        end

        result
      end


      # Get the path where this distribution should be stored
      def distribution_path
        @machine.data_dir.join("wsl2_distribution").to_s
      end

      # Parse WSL list output to extract distribution information
      def parse_wsl_list_output(output)
        distributions = []

        # Handle UTF-16LE encoding from WSL on Windows
        output = output.force_encoding('UTF-16LE').encode('UTF-8', invalid: :replace, undef: :replace)

        lines = output.lines.map(&:strip).reject(&:empty?)

        # Find the header line (NAME STATE VERSION)
        header_index = lines.find_index { |line| line.match?(/NAME.*STATE.*VERSION/i) }
        return distributions unless header_index

        # Parse distribution lines after the header
        lines[(header_index + 1)..-1].each do |line|
          # Remove default marker (*) and null bytes
          line = line.gsub(/\*/, '').gsub(/\0/, '').strip
          next if line.empty?

          # Split by whitespace and extract fields
          parts = line.split(/\s+/)
          next if parts.length < 3

          distributions << {
            name: parts[0],
            state: parts[1],
            version: parts[2]
          }
        end

        distributions
      end
    end
  end
end

require_relative "errors"