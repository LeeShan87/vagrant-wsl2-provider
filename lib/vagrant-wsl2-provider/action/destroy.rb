module VagrantPlugins
  module WSL2
    module Action
      class Destroy
        def initialize(app, env)
          @app = app
        end

        def call(env)
          machine = env[:machine]
          driver = env[:wsl2_driver]

          if machine.id
            env[:ui].info "Destroying WSL2 distribution: #{machine.id}"

            # Halt the distribution first if it's running
            if driver.state == :running
              env[:ui].info "Stopping WSL2 distribution before destroy"
              driver.halt
            end

            # Destroy the distribution
            driver.destroy

            # Clear the machine ID
            machine.id = nil

            env[:ui].info "WSL2 distribution destroyed"
          else
            env[:ui].info "WSL2 distribution not created, nothing to destroy"
          end

          @app.call(env)
        end
      end
    end
  end
end