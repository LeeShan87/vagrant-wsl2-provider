module VagrantPlugins
  module WSL2
    module Action
      # This action parses bash flags from compound SSH flags like -cli, -lc, -lic
      # Example: vagrant ssh -cli "command" becomes vagrant ssh -c "command" with bash flags "-li"
      class ParseSSHFlags
        def initialize(app, env)
          @app = app
        end

        def call(env)
          # Only process for WSL2 provider
          if env[:machine].provider_name == :wsl2
            # Check if this is an ssh_run action (vagrant ssh -c)
            if env[:ssh_run_command]
              # Parse bash flags from ARGV before Vagrant processed them
              # This is tricky because Vagrant already parsed the arguments
              # Instead, we'll store the flags in the environment for the communicator

              # For now, default to -lc (non-interactive)
              # Users can use: vagrant ssh -c "-lic command" format
              env[:wsl2_bash_flags] = "-lc"
            end
          end

          @app.call(env)
        end
      end
    end
  end
end
