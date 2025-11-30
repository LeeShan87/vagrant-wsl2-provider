require 'logger'
require 'pathname'
require 'timeout'
require 'shellwords'
require 'log4r'
require 'vagrant/util/file_mode'
require 'vagrant/util/platform'

module VagrantPlugins
  module WSL2
    # This class provides communication with the WSL2 distribution via wsl.exe commands.
    # It replaces SSH-based communication with direct WSL command execution.
    class Communicator < Vagrant.plugin("2", :communicator)
      # Command to check if the system is ready
      READY_COMMAND = "echo ready"

      def self.match?(machine)
        # Only match WSL2 provider
        machine.provider_name == :wsl2
      end

      def initialize(machine)
        @machine = machine
        @logger = Log4r::Logger.new("vagrant::communication::wsl2")
      end

      def wait_for_ready(timeout)
        Timeout.timeout(timeout) do
          @machine.ui.detail("Waiting for WSL2 distribution to be ready...")

          while true
            begin
              # Check if the distribution is running and responsive
              return true if ready?
            rescue => e
              @logger.debug("WSL2 not ready: #{e.message}")
            end
            sleep 0.5
          end
        end
      rescue Timeout::Error
        @logger.warn("Timeout waiting for WSL2 to be ready")
        return false
      end

      def ready?
        @logger.debug("Checking whether WSL2 distribution is ready...")

        # Check if distribution exists and is running
        driver = @machine.provider.driver
        state = driver.state

        unless state == :running
          @logger.info("WSL2 distribution is not running: #{state}")
          return false
        end

        # Verify we can execute commands
        begin
          exit_code = execute(READY_COMMAND, error_check: false)
          if exit_code == 0
            @logger.info("WSL2 distribution is ready!")
            return true
          else
            @logger.info("WSL2 ready check failed with exit code: #{exit_code}")
            return false
          end
        rescue => e
          @logger.info("WSL2 ready check failed: #{e.message}")
          return false
        end
      end

      def execute(command, opts = nil, &block)
        opts = {
          error_check: true,
          error_class: Vagrant::Errors::VagrantError,
          error_key: :ssh_bad_exit_status,
          good_exit: 0,
          command: command,
          shell: nil,
          sudo: false
        }.merge(opts || {})

        opts[:good_exit] = Array(opts[:good_exit])

        @logger.info("Execute: #{command} (sudo=#{opts[:sudo].inspect})")

        # Parse bash flags from command if present (e.g., "-lci command" or "-lic command")
        bash_flags, actual_command = parse_bash_flags(command)

        # Prepare the command
        wrapped_command = wrap_command(actual_command, opts[:sudo], opts[:shell])

        # Execute via WSL
        driver = @machine.provider.driver
        config = @machine.provider_config

        stdout = ""
        stderr = ""
        exit_status = nil

        begin
          # Build the wsl command with parsed bash flags
          # Use machine.id (persisted) or fallback to config.distribution_name
          distribution_name = @machine.id || config.distribution_name
          wsl_args = ["wsl", "--distribution", distribution_name, "-u", "vagrant",
          "--exec", "bash", bash_flags, wrapped_command]

          # Execute the command
          if block
            # With block: specify notify subscriptions
            result = Vagrant::Util::Subprocess.execute(*wsl_args, notify: [:stdout, :stderr]) do |io_name, data|
              if io_name == :stdout
                stdout += data
                block.call(:stdout, data)
              elsif io_name == :stderr
                # Filter out known harmless warnings
                filtered_data = filter_stderr_warnings(data)
                stderr += filtered_data
                block.call(:stderr, filtered_data) if !filtered_data.empty?
              end
            end
          else
            # Without block: simple execution
            result = Vagrant::Util::Subprocess.execute(*wsl_args)
            stdout = result.stdout
            stderr = filter_stderr_warnings(result.stderr)
          end

          exit_status = result.exit_code
        rescue => e
          @logger.error("Command execution failed: #{e.message}")
          raise
        end

        # Check for errors
        if opts[:error_check] && !opts[:good_exit].include?(exit_status)
          error_opts = opts.merge(
            _key: opts[:error_key],
            stdout: stdout,
            stderr: stderr
          )
          raise opts[:error_class], error_opts
        end

        exit_status
      end

      def sudo(command, opts = nil, &block)
        # Run execute but with the sudo option
        opts = { sudo: true }.merge(opts || {})
        execute(command, opts, &block)
      end

      def test(command, opts = nil)
        opts = { error_check: false }.merge(opts || {})
        execute(command, opts) == 0
      end

      def upload(from, to)
        @logger.debug("Uploading: #{from} to #{to}")

        driver = @machine.provider.driver
        config = @machine.provider_config

        # Convert Windows path to WSL path for the source
        from_path = File.expand_path(from)

        # Get the distribution's filesystem root path
        # WSL distributions are accessible at \\wsl$\<distro-name>\
        distribution_name = @machine.id || config.distribution_name
        wsl_network_path = "\\\\wsl$\\#{distribution_name}"

        # Ensure the distribution is running
        unless driver.state == :running
          raise Vagrant::Errors::VagrantError.new,
            "Distribution must be running to upload files"
        end

        # Build the destination path
        # Remove leading slash if present to avoid double slashes
        to_normalized = to.start_with?('/') ? to[1..-1] : to
        dest_path = File.join(wsl_network_path, to_normalized)

        if File.directory?(from_path)
          # Handle directory upload
          if from_path.end_with?(".")
            @logger.debug("Uploading directory contents of: #{from_path}")
            from_path = from_path.sub(/\.$/, "")
          else
            @logger.debug("Uploading full directory container of: #{from_path}")
            # Create parent directory in WSL
            execute("mkdir -p '#{to}'")
            dest_path = File.join(dest_path, File.basename(from_path))
          end

          # Ensure destination exists
          dest_in_guest = File.join(to, File.basename(from_path))
          execute("mkdir -p '#{dest_in_guest}'")

          # Copy directory recursively
          copy_directory(from_path, dest_path)
        else
          # Handle single file upload
          if to.end_with?('/')
            dest_in_guest = File.join(to, File.basename(from_path))
            execute("mkdir -p '#{to}'")
          else
            dest_in_guest = to
            execute("mkdir -p '#{File.dirname(to)}'")
          end

          # Copy the file
          FileUtils.cp(from_path, dest_path)
        end
      rescue => e
        @logger.error("Upload failed: #{e.message}")
        raise Vagrant::Errors::VagrantError.new,
          "Failed to upload #{from} to #{to}: #{e.message}"
      end

      def download(from, to = nil)
        @logger.debug("Downloading: #{from} to #{to}")

        driver = @machine.provider.driver
        config = @machine.provider_config

        # Ensure the distribution is running
        unless driver.state == :running
          raise Vagrant::Errors::VagrantError.new,
            "Distribution must be running to download files"
        end

        # Get the source path in WSL network share
        distribution_name = @machine.id || config.distribution_name
        wsl_network_path = "\\\\wsl$\\#{distribution_name}"
        from_normalized = from.start_with?('/') ? from[1..-1] : from
        source_path = File.join(wsl_network_path, from_normalized)

        # Copy from WSL to local
        to_path = to ? File.expand_path(to) : File.basename(from)
        FileUtils.cp_r(source_path, to_path)
      rescue => e
        @logger.error("Download failed: #{e.message}")
        raise Vagrant::Errors::VagrantError.new,
          "Failed to download #{from} to #{to}: #{e.message}"
      end

      def reset!
        @logger.debug("Resetting communicator...")
        # For WSL2, we just need to ensure the distribution is running
        wait_for_ready(5)
      end

      def generate_environment_export(env_key, env_value)
        # Use standard bash export syntax
        "export #{env_key}=#{Shellwords.escape(env_value)}\n"
      end

      private

      def parse_bash_flags(command)
        # Check if command starts with bash flags (e.g., "-lci", "-lic", "-l", etc.)
        # Format: "-<flags> actual_command" where flags are bash options
        if command =~ /^-([a-z]+)\s+(.+)$/i
          flags = $1
          actual_command = $2

          # Build bash flag string (e.g., "-lci")
          bash_flags = "-#{flags}"

          @logger.debug("Parsed bash flags: #{bash_flags}")
          return [bash_flags, actual_command]
        end

        # Default: use non-interactive login shell
        return ["-lc", command]
      end

      def filter_stderr_warnings(stderr_data)
        return "" if stderr_data.nil? || stderr_data.empty?

        # Filter out known harmless warnings that occur due to WSL's non-PTY execution
        lines = stderr_data.lines
        filtered_lines = lines.reject do |line|
          # Filter "screen" terminal size warnings
          line =~ /your \d+x\d+ screen size is bogus/ ||
          line =~ /expect trouble/ ||
          # Filter bash job control messages like "[1] 907"
          line =~ /^\[\d+\]\s+\d+\s*$/ ||
          # Filter sudo informational messages
          line =~ /To run a command as administrator/ ||
          line =~ /See "man sudo_root" for details/
        end

        filtered_lines.join
      end

      def wrap_command(command, sudo, shell)
        # Determine the shell to use
        shell_cmd = shell || "bash"

        # Wrap in sudo if requested
        if sudo
          # Use sudo -E to preserve environment
          "sudo -E #{shell_cmd} -c #{Shellwords.escape(command)}"
        else
          command
        end
      end

      def copy_directory(source, dest)
        # Recursively copy directory contents
        Dir.glob(File.join(source, "**", "*"), File::FNM_DOTMATCH).each do |item|
          next if File.basename(item) == "." || File.basename(item) == ".."

          relative_path = item.sub(/^#{Regexp.escape(source)}/, "")
          dest_item = File.join(dest, relative_path)

          if File.directory?(item)
            FileUtils.mkdir_p(dest_item) unless File.exist?(dest_item)
          else
            FileUtils.mkdir_p(File.dirname(dest_item)) unless File.exist?(File.dirname(dest_item))
            FileUtils.cp(item, dest_item)
          end
        end
      end
    end
  end
end
