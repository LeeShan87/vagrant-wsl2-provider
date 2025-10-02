require "vagrant/action/builder"
require "fileutils"

module VagrantPlugins
  module WSL2
    module Action
      class Create
        def initialize(app, env)
          @app = app
        end

        def call(env)
          machine = env[:machine]
          config = machine.provider_config
          driver = env[:wsl2_driver]

          env[:ui].info "Creating WSL2 distribution: #{config.distribution_name}"

          # Check if distribution already exists
          if driver.state != :not_created
            raise Errors::DistributionAlreadyExists,
                  name: config.distribution_name
          end

          # Use the box name as WSL distribution name from Microsoft Store
          box_name = machine.config.vm.box
          clean_base_name = "#{box_name}-vagrant-base"
          cache_dir = get_cache_directory

          env[:ui].info "Using WSL distribution: #{box_name}"

          # Check if the distribution is available online
          unless wsl_distribution_available?(box_name)
            raise Errors::WSLDistributionNotFound,
                  name: box_name
          end

          # Check if we have a clean cached version
          cached_tar_path = File.join(cache_dir, "#{clean_base_name}.tar")

          unless File.exist?(cached_tar_path)
            # Check if the original distribution already exists (dirty)
            if wsl_distribution_installed?(box_name)
              raise Errors::DirtyDistributionExists,
                    name: box_name,
                    clean_name: clean_base_name,
                    cache_path: cache_dir
            end

            # Create clean base distribution
            env[:ui].info "Creating clean base distribution: #{clean_base_name}"
            create_clean_base_distribution(env, box_name, clean_base_name, cached_tar_path, cache_dir, driver)
          end

          # Create project-specific distribution from clean base
          env[:ui].info "Creating project-specific distribution: #{config.distribution_name}"
          create_project_distribution_from_cache(env, cached_tar_path, config.distribution_name, driver)

          # Set up vagrant user in the new distribution
          env[:ui].info "Setting up vagrant user and environment"
          setup_vagrant_user(env, config.distribution_name)

          # Apply wsl.conf configuration
          env[:ui].info "Applying wsl.conf configuration"
          driver.apply_wsl_conf

          # Set the project distribution as default only if cache is currently default
          current_default = get_current_default_distribution
          if current_default == clean_base_name
            env[:ui].info "Setting project distribution as default (was cache)"
            Vagrant::Util::Subprocess.execute("wsl", "--set-default", config.distribution_name)
          else
            env[:ui].info "Keeping existing default distribution: #{current_default}"
          end

          # Set the machine ID
          machine.id = config.distribution_name

          env[:ui].info "WSL2 distribution created successfully"

          @app.call(env)
        end

        private

        def wsl_distribution_available?(name)
          result = Vagrant::Util::Subprocess.execute("wsl", "--list", "--online")
          return false if result.exit_code != 0

          # Handle potential encoding issues - WSL output is UTF-16LE on Windows
          output = result.stdout.force_encoding('UTF-16LE').encode('UTF-8', invalid: :replace, undef: :replace)

          # Find the line with NAME header and start parsing from the next line
          lines = output.lines.map(&:strip)
          name_header_index = lines.find_index { |line| line.start_with?("NAME") }

          return false unless name_header_index

          # Parse lines after the NAME header
          lines[(name_header_index + 1)..-1].any? do |line|
            # Skip empty lines
            next if line.empty?

            # Extract the first word (distribution name) before whitespace
            distro_name = line.split(/\s+/).first
            distro_name == name
          end
        end

        def wsl_distribution_installed?(name)
          result = Vagrant::Util::Subprocess.execute("wsl", "--list", "--quiet")

          # If no distributions exist, wsl --list returns non-zero exit code
          # This is expected and not an error
          return false if result.exit_code != 0

          # Handle UTF-16LE encoding from WSL on Windows
          output = result.stdout.force_encoding('UTF-16LE').encode('UTF-8', invalid: :replace, undef: :replace)

          # Check if the distribution name appears in the output
          output.lines.any? { |line| line.strip == name }
        rescue
          # If any error occurs, assume distribution is not installed
          false
        end

        def install_wsl_distribution(name, driver)
          # Use proper non-interactive WSL installation
          success = system("wsl", "--install", "--distribution", name, "--no-launch")
          exit_code = success ? 0 : $?.exitstatus

          case exit_code
          when 0
            # Installation command succeeded - wait and verify
            wait_for_distribution_installation(name)
          when 1
            raise Errors::WSLInstallFailed,
                  name: name,
                  stderr: "General WSL installation error. Check internet connection and Windows Store access."
          when 2
            raise Errors::WSLInstallFailed,
                  name: name,
                  stderr: "Invalid distribution name or parameters."
          when 3221225485
            raise Errors::WSLInstallFailed,
                  name: name,
                  stderr: "WSL installation requires a system restart to complete."
          when 3221225506
            raise Errors::WSLInstallFailed,
                  name: name,
                  stderr: "WSL feature is not enabled. Enable WSL in Windows Features."
          else
            raise Errors::WSLInstallFailed,
                  name: name,
                  stderr: "Unknown installation error (exit code: #{exit_code})"
          end
        end

        def wait_for_distribution_installation(name, timeout = 30)
          start_time = Time.now

          # Give it a moment for the distribution to appear
          sleep 3

          # Check if distribution was created
          if wsl_distribution_installed?(name)
            return true
          end

          # If not found immediately, wait a bit more and check again
          loop do
            sleep 2
            if wsl_distribution_installed?(name)
              return true
            end

            if Time.now - start_time > timeout
              raise Errors::WSLInstallFailed,
                    name: name,
                    stderr: "Distribution '#{name}' not found after installation completed. Check if installation was successful."
            end
          end
        end

        def get_cache_directory
          # Use Vagrant's data directory instead of relying on HOME environment variable
          cache_dir = File.join(Vagrant.user_data_path, "wsl2-cache")
          FileUtils.mkdir_p(cache_dir) unless File.exist?(cache_dir)
          cache_dir
        end

        def create_clean_base_distribution(env, box_name, clean_base_name, cached_tar_path, cache_dir, driver)
          # Install fresh distribution
          env[:ui].info "Installing fresh WSL distribution: #{box_name}"
          install_wsl_distribution(box_name, driver)

          # Export to cache
          env[:ui].info "Exporting clean distribution to cache: #{cached_tar_path}"
          begin
            driver.execute_command("wsl", "--export", box_name, cached_tar_path)
          rescue Errors::WSLCommandFailed => e
            raise Errors::WSLExportFailed,
                  name: box_name,
                  stderr: e.message
          end

          # Remove the original to prevent contamination
          env[:ui].info "Removing original distribution to prevent contamination"
          Vagrant::Util::Subprocess.execute("wsl", "--unregister", box_name)

        end

        def get_current_default_distribution
          result = Vagrant::Util::Subprocess.execute("wsl", "--list", "--quiet")
          return nil if result.exit_code != 0

          # Handle UTF-16LE encoding from WSL on Windows
          output = result.stdout.force_encoding('UTF-16LE').encode('UTF-8', invalid: :replace, undef: :replace)

          # The first line is the default distribution
          output.lines.first&.strip
        end

        def setup_vagrant_user(env, distribution_name)
          # Create vagrant user with home directory
          run_in_distribution(env, distribution_name, [
            "useradd -m -s /bin/bash vagrant || true",  # Allow if user exists
            "echo 'vagrant:vagrant' | chpasswd",
            "usermod -aG sudo vagrant 2>/dev/null || usermod -aG wheel vagrant 2>/dev/null || true"
          ])

          # Set up sudo without password
          run_in_distribution(env, distribution_name, [
            "echo 'vagrant ALL=(ALL) NOPASSWD:ALL' | tee /etc/sudoers.d/vagrant",
            "chmod 440 /etc/sudoers.d/vagrant"
          ])

          # Set up home directory permissions
          run_in_distribution(env, distribution_name, [
            "chown vagrant:vagrant /home/vagrant",
            "chmod 755 /home/vagrant"
          ])

          # Set up SSH directory for future use
          run_in_distribution(env, distribution_name, [
            "mkdir -p /home/vagrant/.ssh",
            "chmod 700 /home/vagrant/.ssh",
            "chown vagrant:vagrant /home/vagrant/.ssh"
          ])

          # Copy skeleton files
          run_in_distribution(env, distribution_name, [
            "cp /etc/skel/.bashrc /home/vagrant/ 2>/dev/null || true",
            "cp /etc/skel/.profile /home/vagrant/ 2>/dev/null || true",
            "chown vagrant:vagrant /home/vagrant/.bashrc /home/vagrant/.profile 2>/dev/null || true"
          ])
        end

        def run_in_distribution(env, distribution_name, commands)
          commands.each do |command|
            result = Vagrant::Util::Subprocess.execute(
              "wsl", "-d", distribution_name, "-u", "root", "--", "bash", "-c", command
            )

            # Don't fail on non-critical setup commands
            if result.exit_code != 0
              env[:ui].warn "Command failed (continuing): #{command}"
              env[:ui].error "#{result.stderr}" unless result.stderr.empty?
            end
          end
        end

        def create_project_distribution_from_cache(env, cached_tar_path, target_name, driver)
          # Import project-specific distribution directly from cache
          env[:ui].info "Creating WSL2 distribution '#{target_name}' from cached image: #{cached_tar_path}"
          driver.create(cached_tar_path)
        end

        def create_project_distribution(source_name, target_name, driver)
          # Create temporary export path
          temp_export = File.join(Dir.tmpdir, "#{target_name}-export.tar")

          begin
            # Export the base distribution
            begin
              driver.execute_command("wsl", "--export", source_name, temp_export)
            rescue Errors::WSLCommandFailed => e
              raise Errors::WSLExportFailed,
                    name: source_name,
                    stderr: e.message
            end

            # Import as project-specific distribution
            driver.create(temp_export)

          ensure
            # Clean up temporary file
            File.delete(temp_export) if File.exist?(temp_export)
          end
        end
      end
    end
  end
end