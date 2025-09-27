require "vagrant/action/builder"

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

          # Get the box path (assuming it's a tar.gz)
          box_path = machine.box.directory.join("box.tar.gz")
          unless File.exist?(box_path)
            raise Vagrant::Errors::BoxNotFound,
                  name: machine.box.name,
                  provider: machine.provider_name
          end

          # Create the distribution
          driver.create(box_path)

          # Set the machine ID
          machine.id = config.distribution_name

          env[:ui].info "WSL2 distribution created successfully"

          @app.call(env)
        end
      end
    end
  end
end