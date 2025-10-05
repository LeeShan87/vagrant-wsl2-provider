module VagrantPlugins
  module WSL2
    module Cap
      class SnapshotList
        def self.snapshot_list(machine)
          driver = machine.provider.instance_variable_get(:@driver)
          driver.list_snapshots
        end
      end
    end
  end
end
