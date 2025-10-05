require "vagrant/util/subprocess"
require "fileutils"

module VagrantPlugins
  module WSL2
    class Driver
      def initialize(machine)
        @machine = machine
        @config = machine.provider_config
      end

      # Get the current state of the WSL2 distribution
      def state
        # Check if distribution exists by trying to get its state
        result = Vagrant::Util::Subprocess.execute("wsl", "--distribution", @config.distribution_name, "--exec", "echo")

        case result.exit_code
        when 0
          # Distribution exists and is accessible, check if running
          running_result = Vagrant::Util::Subprocess.execute("wsl", "--distribution", @config.distribution_name, "--exec", "true")
          return running_result.exit_code == 0 ? :running : :stopped
        when 1, 4294967295
          # Distribution doesn't exist or WSL error
          :not_created
        else
          # Unknown error state
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
        execute("wsl", "--import", @config.distribution_name,
                dist_dir, box_path, "--version", @config.version.to_s)
      end

      # Start the WSL2 distribution
      def start
        @machine.ui.info "Starting WSL2 distribution: #{@config.distribution_name}"
        execute("wsl", "--distribution", @config.distribution_name, "--exec", "true")
      end

      # Stop the WSL2 distribution
      def halt
        @machine.ui.info "Stopping WSL2 distribution: #{@config.distribution_name}"
        execute("wsl", "--terminate", @config.distribution_name)
      end

      # Destroy the WSL2 distribution
      def destroy
        execute("wsl", "--unregister", @config.distribution_name)

        # Clean up distribution files
        dist_path = distribution_path
        FileUtils.rm_rf(dist_path) if File.exist?(dist_path)
      end

      # Execute a command in the WSL2 distribution
      def execute_in_wsl(*args)
        execute("wsl", "--distribution", @config.distribution_name, *args)
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
        execute("wsl", "--export", @config.distribution_name, snapshot_file)

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
        execute("wsl", "--unregister", @config.distribution_name)

        # Import the snapshot as the distribution
        dist_dir = distribution_path
        FileUtils.mkdir_p(dist_dir) unless File.exist?(dist_dir)

        execute("wsl", "--import", @config.distribution_name,
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
    end
  end
end

require_relative "errors"