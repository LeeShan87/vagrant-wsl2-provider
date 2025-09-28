require "vagrant"

module VagrantPlugins
  module WSL2
    module Action
      class ShareFolders
        def initialize(app, env)
          @app = app
        end

        def call(env)
          # Set up shared folders for WSL2 BEFORE calling next action
          env[:ui].info "Setting up shared folders for WSL2 distribution"
          setup_shared_folders(env)

          @app.call(env)
        end

        private

        def setup_shared_folders(env)
          machine = env[:machine]
          distribution_name = machine.id

          return if distribution_name.nil?

          # Get shared folders configuration
          shared_folders = {}

          # Add default /vagrant folder (always enabled unless explicitly disabled in synced_folders)
          unless machine.config.vm.synced_folders["/vagrant"] && machine.config.vm.synced_folders["/vagrant"][:disabled]
            shared_folders["/vagrant"] = {
              hostpath: machine.env.cwd.to_s,
              guestpath: "/vagrant",
              disabled: false
            }
          end

          # Add user-defined shared folders
          machine.config.vm.synced_folders.each do |id, data|
            next if data[:disabled]
            shared_folders[data[:guestpath]] = data
          end

          # Create shared folders in WSL2
          shared_folders.each do |guestpath, data|
            create_shared_folder(env, distribution_name, data[:hostpath], guestpath)
          end
        end

        def create_shared_folder(env, distribution_name, hostpath, guestpath)
          # Convert Windows path to WSL2 path
          # Handle both full paths and relative paths
          if hostpath.match(/^[A-Z]:[\\\/]/)
            # Full Windows path
            wsl_hostpath = hostpath.gsub("\\", "/").gsub(/^([A-Z]):/, '/mnt/\1').downcase
          else
            # Relative path - convert to absolute first
            absolute_path = File.expand_path(hostpath)
            wsl_hostpath = absolute_path.gsub("\\", "/").gsub(/^([A-Z]):/, '/mnt/\1').downcase
          end

          env[:ui].info "Creating shared folder: #{hostpath} -> #{guestpath}"

          # Create the shared folder using symlink
          commands = [
            "mkdir -p #{File.dirname(guestpath)}",
            "rm -rf #{guestpath}",
            "ln -sf #{wsl_hostpath} #{guestpath}",
            "chown -h vagrant:vagrant #{guestpath}"
          ]

          commands.each do |command|
            result = Vagrant::Util::Subprocess.execute(
              "wsl", "-d", distribution_name, "-u", "root", "--",
              "bash", "-c", command
            )

            if result.exit_code != 0
              raise Vagrant::Errors::VagrantError,
                    "Failed to create shared folder: #{command}"
            end
          end
        end
      end
    end
  end
end