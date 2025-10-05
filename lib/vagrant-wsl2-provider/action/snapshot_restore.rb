module VagrantPlugins
  module WSL2
    module Action
      class SnapshotRestore
        def initialize(app, env)
          @app = app
        end

        def call(env)
          driver = env[:wsl2_driver]
          snapshot_name = env[:snapshot_name]

          if snapshot_name.nil? || snapshot_name.empty?
            raise Vagrant::Errors::SnapshotNameRequired
          end

          driver.restore_snapshot(snapshot_name)

          @app.call(env)
        end
      end
    end
  end
end
