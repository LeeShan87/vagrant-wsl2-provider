module VagrantPlugins
  module WSL2
    module Action
      class Halt
        def initialize(app, env)
          @app = app
        end

        def call(env)
          machine = env[:machine]
          driver = env[:wsl2_driver]

          if machine.id
            case driver.state
            when :stopped
              env[:ui].info "WSL2 distribution is already stopped"
            when :running
              env[:ui].info "Stopping WSL2 distribution: #{machine.id}"
              driver.halt
              env[:ui].info "WSL2 distribution stopped"
            else
              env[:ui].warn "WSL2 distribution is in unknown state"
            end
          else
            raise Errors::DistributionNotFound
          end

          @app.call(env)
        end
      end
    end
  end
end