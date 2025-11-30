module VagrantPlugins
  module WSL2
    module Action
      # Silently ensure the WSL2 distribution is running
      # This is used by SSH commands when the distribution is stopped
      # WSL2 automatically stops idle distributions, so this is expected behavior
      class EnsureRunning
        def initialize(app, env)
          @app = app
        end

        def call(env)
          driver = env[:wsl2_driver]

          # Only start if stopped, do nothing if already running
          # Use silent: true to avoid polluting SSH command output
          if driver.state == :stopped
            driver.start(silent: true)
          end

          @app.call(env)
        end
      end
    end
  end
end
