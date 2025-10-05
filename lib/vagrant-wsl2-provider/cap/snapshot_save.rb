module VagrantPlugins
  module WSL2
    module Cap
      class SnapshotSave
        def self.snapshot_save(machine, snapshot_name)
          driver = machine.provider.instance_variable_get(:@driver)
          driver.save_snapshot(snapshot_name)
        end
      end
    end
  end
end
