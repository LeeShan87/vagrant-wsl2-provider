module VagrantPlugins
  module WSL2
    module Cap
      class SnapshotRestore
        def self.snapshot_restore(machine, snapshot_name)
          driver = machine.provider.instance_variable_get(:@driver)
          driver.restore_snapshot(snapshot_name)
        end
      end
    end
  end
end
