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
        execute("wsl", "--distribution", @config.distribution_name, "--exec", "true")
      end

      # Stop the WSL2 distribution
      def halt
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

      private

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