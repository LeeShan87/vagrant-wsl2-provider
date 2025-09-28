module VagrantPlugins
  module WSL2
    module Action
      class PrepareEnvironment
        def initialize(app, env)
          @app = app
        end

        def call(env)
          # Set up the WSL2 driver in the environment
          env[:wsl2_driver] = Driver.new(env[:machine])

          # Ensure we're on Windows
          unless Vagrant::Util::Platform.windows?
            raise Errors::WindowsRequired
          end

          @app.call(env)
        end
      end
    end
  end
end