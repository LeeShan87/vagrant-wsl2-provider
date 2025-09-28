module VagrantPlugins
  module WSL2
    module Action
      class WSLShell
        def initialize(app, env)
          @app = app
        end

        def call(env)
          machine = env[:machine]

          if machine.id.nil?
            raise Errors::DistributionNotFound
          end

          # Start an interactive shell in the WSL2 distribution as vagrant user
          env[:ui].info "Connecting to WSL2 distribution: #{machine.id}"

          # Change to vagrant user's home directory and start bash
          system("wsl", "-d", machine.id, "-u", "vagrant", "--", "bash", "-l")

          @app.call(env)
        end
      end
    end
  end
end