require "vagrant"
require "vagrant/util/platform"

module VagrantPlugins
  module WSL2
    class Provider < Vagrant.plugin("2", :provider)
      def initialize(machine)
        @machine = machine
        @driver = Driver.new(@machine)
      end

      # Returns the SSH info for accessing the machine
      def ssh_info
        return nil if state.id != :running

        {
          host: "localhost",
          port: 22,
          username: "vagrant",
          private_key_path: @machine.data_dir.join("private_key").to_s,
        }
      end

      # Returns the current state of the machine
      def state
        state_id = nil
        state_id = @driver.state if @driver

        state_id = :not_created if state_id.nil?

        short = state_id.to_s.gsub("_", " ")
        long = I18n.t("vagrant_wsl2.states.#{state_id}")

        Vagrant::MachineState.new(state_id, short, long)
      end

      # Returns a human-friendly string version of this provider
      def to_s
        id = @machine.id || "new"
        "WSL2 (#{id})"
      end

      # This method is called if the underlying machine ID changes
      def machine_id_changed
        # Nothing to do
      end

      # Provider capabilities
      def capability(cap_name)
        case cap_name
        when :halt
          @driver.halt
        when :destroy
          @driver.destroy
        else
          super
        end
      end

      private

      def ensure_windows_platform!
        unless Vagrant::Util::Platform.windows?
          raise Errors::WindowsRequired
        end
      end
    end
  end
end

require_relative "driver"