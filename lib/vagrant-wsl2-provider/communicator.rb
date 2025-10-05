require "vagrant"

module VagrantPlugins
  module WSL2
    class Communicator < Vagrant.plugin("2", :communicator)
      def self.match?(machine)
        # Use this communicator for WSL2 provider
        machine.provider_name == :wsl2
      end

      def initialize(machine)
        @machine = machine
        @logger = Log4r::Logger.new("vagrant::communication::wsl2")
      end

      def ready?
        # WSL2 distribution is always ready if it exists
        @machine.state.id != :not_created
      end

      def execute(command, opts = {}, &block)
        # Execute command in WSL2 distribution as vagrant user
        distribution_name = @machine.id
        return 1 if distribution_name.nil?

        @logger.debug("Executing command in WSL2: #{command}")

        # Set up IO for real-time output
        io_stdin = opts[:stdin] if opts[:stdin]
        io_stdout = opts[:stdout] if opts[:stdout]
        io_stderr = opts[:stderr] if opts[:stderr]

        # Encode command using base64 to avoid shell escaping issues
        encoded_command = encode_command(command)

        result = Vagrant::Util::Subprocess.execute(
          "wsl", "-d", distribution_name, "-u", "vagrant", "--",
          "bash", "-l", "-c", encoded_command,
          :notify => [:stdin, :stdout, :stderr]
        ) do |type, data|
          # Call the block if provided (for SSH run command output)
          if block_given?
            block.call(type, data)
          end

          case type
          when :stdout
            io_stdout.write(data) if io_stdout
            puts data if !io_stdout && !block_given?
          when :stderr
            io_stderr.write(data) if io_stderr
            $stderr.puts data if !io_stderr && !block_given?
          end
        end

        # puts "DEBUG: WSL2 command result: exit_code=#{result.exit_code}" if ENV['VAGRANT_DEBUG']

        # Handle output if needed
        if opts[:error_check] != false && result.exit_code != 0
          raise Vagrant::Errors::VagrantError,
                "Command failed with exit code #{result.exit_code}: #{command}"
        end

        result.exit_code
      end

      def sudo(command, opts = {})
        # Use sudo in WSL2 distribution
        # puts "*** WSL2 SUDO COMMAND: sudo #{command} ***"  # Debug sudo commands
        @logger.debug("Executing sudo command in WSL2: sudo #{command}")
        execute("sudo #{command}", opts)
      end

      def download(from, to = nil)
        @logger.warn("Download not implemented for WSL2 communicator")
      end

      def upload(from, to)
        # Upload file to WSL2 distribution
        distribution_name = @machine.id
        return if distribution_name.nil?

        # puts "*** WSL2 UPLOAD: #{from} -> #{to} ***"  # Debug
        @logger.debug("Uploading #{from} to #{to} in WSL2")

        # Read local file and write to WSL2
        content = File.read(from)
        # puts "*** WSL2 UPLOAD CONTENT LENGTH: #{content.length} ***"

        # Create directory if needed
        dir = File.dirname(to)
        execute("mkdir -p #{dir}")

        # Write file content using base64 encoding to avoid shell escaping issues
        require 'base64'
        encoded_content = Base64.strict_encode64(content)
        # Direct base64 command - no need for encode_command here as it's already base64
        result = Vagrant::Util::Subprocess.execute(
          "wsl", "-d", distribution_name, "-u", "vagrant", "--",
          "bash", "-c", "echo '#{encoded_content}' | base64 -d > #{to}"
        )

        # puts "*** WSL2 UPLOAD RESULT: #{result.exit_code} ***"

        if result.exit_code != 0
          # puts "*** WSL2 UPLOAD ERROR: #{result.stderr} ***"
          raise Vagrant::Errors::VagrantError,
                "Failed to upload file to WSL2: #{result.stderr}"
        end

        # Make uploaded file executable if it's a script
        if to.include?('/tmp/vagrant-shell')
          execute("chmod +x #{to}")
        end
      end

      def test(command, opts = {})
        # Test command (return true/false)
        result = execute(command, opts.merge(error_check: false))
        result == 0
      end

  def shell_expand_guest_path(path)
    # WSL2-specific shell path expansion implementation
    distribution_name = @machine.id
    return path if distribution_name.nil?

    @logger.debug("Expanding shell path: #{path}")

    # Escape spaces and use printf for proper shell expansion
    escaped_path = path.gsub(/ /, '\\ ')
    real_path = nil

    # Execute printf command to expand the path
    result = Vagrant::Util::Subprocess.execute(
      "wsl", "-d", distribution_name, "-u", "vagrant", "--",
      "bash", "-c", "printf #{escaped_path}"
    )

    if result.exit_code == 0 && !result.stdout.strip.empty?
      expanded_path = result.stdout.strip
      @logger.debug("Path expanded from #{path} to #{expanded_path}")
      expanded_path
    else
      @logger.debug("Path expansion failed, returning original path: #{path}")
      path
    end
  end
      

      private

      def encode_command(command)
        # Use base64 encoding to completely avoid shell escaping issues
        # This is much more reliable than trying to escape complex shell commands

        # Fix multiline sudo commands by ensuring all lines have sudo
        fixed_command = fix_multiline_sudo(command)

        require 'base64'
        encoded = Base64.strict_encode64(fixed_command)
        result_cmd = "echo '#{encoded}' | base64 -d | bash"
        # puts "*** WSL2 BASE64 ENCODING: #{command.length} chars -> #{encoded.length} chars ***"
        result_cmd
      end

      def fix_multiline_sudo(command)
        # Fix commands that start with sudo but have multiline continuation OR pipe operations
        if command.strip.start_with?('sudo')
          # Handle multiline commands
          if command.include?("\n")
            lines = command.split("\n")
            first_line = lines[0].strip

            if first_line == 'sudo' && lines.length > 1
              # Combine all lines into a single sudo command, preserving && structure
              remaining_lines = lines[1..-1].join(' ').strip

              # For commands with &&, wrap the entire command sequence in sudo bash -c
              if remaining_lines.include?('&&')
                "sudo bash -c '#{remaining_lines}'"
              else
                "sudo #{remaining_lines}"
              end
            else
              command
            end
          # Handle pipe operations that need sudo for the entire pipeline
          elsif command.include?('|') && command.include?('bash')
            # For commands like "sudo curl ... | bash", wrap entire pipeline in sudo bash -c
            command_without_sudo = command.sub(/^sudo\s+/, '')
            "sudo bash -c '#{command_without_sudo}'"
          else
            command
          end
        else
          command
        end
      end
    end
  end
end