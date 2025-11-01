module VagrantPlugins
  module WSL2
    module Action
      class MountDataDisks
        def initialize(app, env)
          @app = app
        end

        def call(env)
          machine = env[:machine]
          driver = env[:wsl2_driver]

          # Only mount if data disks are configured
          if machine.provider_config.data_disks&.any?
            machine.ui.info "Configuring data disks..."
            driver.mount_data_disks
          end

          @app.call(env)
        end
      end
    end
  end
end
