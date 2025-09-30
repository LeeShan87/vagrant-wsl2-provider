require "vagrant"

module VagrantPlugins
  module WSL2
    module Cap
      class ShellExpandGuestPath
        def self.shell_expand_guest_path(machine, path)
          # Use the WSL2 communicator's shell_expand_guest_path method
          comm = machine.communicate

          # Call the communicator method directly
          if comm.respond_to?(:shell_expand_guest_path)
            return comm.shell_expand_guest_path(path)
          end

          # Fallback: return original path
          path
        end
      end
    end
  end
end