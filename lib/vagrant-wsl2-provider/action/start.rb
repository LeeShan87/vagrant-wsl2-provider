module VagrantPlugins
  module WSL2
    module Action
      class Start
        def initialize(app, env)
          @app = app
        end

        def call(env)
          machine = env[:machine]
          driver = env[:wsl2_driver]

          if machine.id
            case driver.state
            when :running
              env[:ui].info "WSL2 distribution is already running"
            when :stopped
              env[:ui].info "Starting WSL2 distribution: #{machine.id}"
              driver.start
              env[:ui].info "WSL2 distribution started"
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