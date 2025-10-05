module VagrantPlugins
  module WSL2
    module Cap
      class SnapshotDelete
        def self.snapshot_delete(machine, snapshot_name)
          driver = machine.provider.instance_variable_get(:@driver)
          driver.delete_snapshot(snapshot_name)
        end
      end
    end
  end
end
