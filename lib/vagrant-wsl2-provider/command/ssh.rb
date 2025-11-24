require 'optparse'

module VagrantPlugins
  module WSL2
    module Command
      class SSH < Vagrant.plugin("2", :command)
        def self.synopsis
          "connects to machine via SSH (WSL2-enhanced)"
        end

        def execute
          options = {
            bash_flags: "-lc"  # Default: login shell, non-interactive
          }

          # Pre-process @argv to handle compound flags like -cli, -lic, etc.
          # parse_options uses @argv (instance variable), not ARGV (global constant)
          @argv = preprocess_compound_flags(@argv)

          opts = OptionParser.new do |o|
            o.banner = "Usage: vagrant ssh [options] [name|id]"
            o.separator ""
            o.separator "Options:"
            o.separator ""

            # Custom bash flags for WSL2 (-l and -i)
            # IMPORTANT: Define these BEFORE -c so OptionParser knows they're separate flags
            o.on("-l", "Use login shell (sources ~/.bash_profile, ~/.profile)") do
              options[:bash_flags] = modify_flags(options[:bash_flags], 'l')
            end

            o.on("-i", "Use interactive shell (enables job control for background processes)") do
              options[:bash_flags] = modify_flags(options[:bash_flags], 'i')
            end

            # Standard Vagrant SSH options
            o.on("-c", "--command COMMAND", "Execute an SSH command directly") do |c|
              options[:command] = c
            end

            o.on("-p", "--plain", "Plain mode") do
              options[:plain_mode] = true
            end

            o.on("-t", "--[no-]tty", "Enables tty") do |t|
              options[:tty] = t
            end
          end

          # Parse the options
          argv = parse_options(opts)
          return if !argv

          # Get the machine
          with_target_vms(argv, single_target: true) do |machine|
            # Skip if not WSL2 provider
            if machine.provider_name != :wsl2
              # Fall back to default Vagrant SSH
              return @env.cli("ssh", *ARGV)
            end

            # Store bash flags in machine environment for communicator
            machine.env.instance_variable_set(:@wsl2_bash_flags, options[:bash_flags])

            # Execute SSH command
            if options[:command]
              # Store flags in a way the communicator can access
              original_command = options[:command]
              # Prepend flags to command so communicator can parse them
              modified_command = "#{options[:bash_flags]} #{original_command}"

              exit_code = machine.action(:ssh_run, ssh_run_command: modified_command)
              return exit_code
            else
              # Interactive SSH
              machine.action(:ssh, ssh_opts: options)
            end
          end
        end

        private

        def preprocess_compound_flags(argv)
          # Handle compound flags like -cli, -lic, -lc, etc.
          # IMPORTANT: When -c is present, it must come FIRST with its argument,
          # then other flags, so OptionParser doesn't consume other flags as -c's argument
          processed = []
          i = 0

          while i < argv.length
            arg = argv[i]

            # Check if it's a compound flag starting with - and containing 'c'
            if arg =~ /^-([a-z]*c[a-z]*)$/i
              flags = $1

              # Extract the individual flags
              has_c = flags.include?('c')
              has_l = flags.include?('l')
              has_i = flags.include?('i')
              other_flags = flags.gsub(/[cli]/, '')

              # CRITICAL: Add -c with its argument FIRST
              if has_c
                processed << "-c"
                i += 1
                processed << argv[i] if i < argv.length
              end

              # Then add other flags (won't be consumed by -c now)
              processed << "-l" if has_l
              processed << "-i" if has_i
              processed += other_flags.chars.map { |f| "-#{f}" } unless other_flags.empty?
            else
              processed << arg
            end

            i += 1
          end

          processed
        end

        def modify_flags(current_flags, new_flag)
          # Remove leading dash
          flags = current_flags.gsub(/^-/, '')

          # Add new flag if not present
          unless flags.include?(new_flag)
            flags += new_flag
          end

          # Return with dash
          "-#{flags}"
        end
      end
    end
  end
end
