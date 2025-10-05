module VagrantPlugins
  module WSL2
    module Action
      class SSHRun
        def initialize(app, env)
          @app = app
        end

        def call(env)
          # Get the SSH command from environment
          command = env[:ssh_run_command]

          if command
            # Execute the command through the communicator
            # Output directly to stdout/stderr without Vagrant UI formatting
            exit_status = env[:machine].communicate.execute(command, error_check: false) do |type, data|
              case type
              when :stdout
                $stdout.print(data)
                $stdout.flush
              when :stderr
                $stderr.print(data)
                $stderr.flush
              end
            end

            # Set the exit status
            env[:ssh_run_exit_status] = exit_status
          end

          @app.call(env)
        end
      end
    end
  end
end
