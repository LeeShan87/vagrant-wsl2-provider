module VagrantPlugins
  module WSL2
    module Action
      class SnapshotList
        def initialize(app, env)
          @app = app
        end

        def call(env)
          driver = env[:wsl2_driver]
          snapshots = driver.list_snapshots

          if snapshots.empty?
            env[:ui].info "No snapshots found"
          else
            env[:ui].info "Snapshots:"
            snapshots.each do |snapshot|
              env[:ui].info "  - #{snapshot}"
            end
          end

          @app.call(env)
        end
      end
    end
  end
end
