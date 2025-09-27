require "vagrant/util/subprocess"

module VagrantPlugins
  module WSL2
    class Driver
      def initialize(machine)
        @machine = machine
        @config = machine.provider_config
      end

      # Get the current state of the WSL2 distribution
      def state
        result = execute("wsl", "--list", "--verbose")

        distributions = parse_wsl_list_output(result.stdout)
        distro = distributions.find { |d| d[:name] == @config.distribution_name }

        return :not_created unless distro

        case distro[:state]
        when "Running"
          :running
        when "Stopped"
          :stopped
        else
          :unknown
        end
      end

      # Create a new WSL2 distribution
      def create(box_path)
        # Import the distribution from a tar.gz file
        execute("wsl", "--import", @config.distribution_name,
                distribution_path, box_path, "--version", @config.version.to_s)
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

      private

      # Execute a Windows command
      def execute(*args)
        result = Vagrant::Util::Subprocess.execute(*args)

        if result.exit_code != 0
          raise Errors::WSLCommandFailed,
                command: args.join(" "),
                stderr: result.stderr
        end

        result
      end

      # Parse the output of 'wsl --list --verbose'
      def parse_wsl_list_output(output)
        distributions = []

        # Skip header lines and parse each distribution
        lines = output.split("\n")[1..-1] || []

        lines.each do |line|
          next if line.strip.empty?

          # Parse line format: "  NAME    STATE    VERSION"
          parts = line.strip.split(/\s+/)
          next if parts.length < 3

          distributions << {
            name: parts[0].gsub(/\*/, "").strip,
            state: parts[1],
            version: parts[2]
          }
        end

        distributions
      end

      # Get the path where this distribution should be stored
      def distribution_path
        @machine.data_dir.join("wsl2_distribution").to_s
      end
    end
  end
end

require_relative "errors"