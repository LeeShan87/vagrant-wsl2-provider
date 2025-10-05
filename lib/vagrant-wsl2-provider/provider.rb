require "vagrant"
require "vagrant/util/platform"

module VagrantPlugins
  module WSL2
    module Action
      # Import our custom actions
      autoload :Create, File.expand_path("../action/create", __FILE__)
      autoload :Destroy, File.expand_path("../action/destroy", __FILE__)
      autoload :Halt, File.expand_path("../action/halt", __FILE__)
      autoload :Start, File.expand_path("../action/start", __FILE__)
      autoload :PrepareEnvironment, File.expand_path("../action/prepare_environment", __FILE__)
      autoload :WSLShell, File.expand_path("../action/wsl_shell", __FILE__)
      autoload :ShareFolders, File.expand_path("../action/share_folders", __FILE__)
      autoload :SSHRun, File.expand_path("../action/ssh_run", __FILE__)
      autoload :SnapshotList, File.expand_path("../action/snapshot_list", __FILE__)
      autoload :SnapshotSave, File.expand_path("../action/snapshot_save", __FILE__)
      autoload :SnapshotRestore, File.expand_path("../action/snapshot_restore", __FILE__)
      autoload :SnapshotDelete, File.expand_path("../action/snapshot_delete", __FILE__)
    end
    class Provider < Vagrant.plugin("2", :provider)
      def initialize(machine)
        @machine = machine
        @driver = Driver.new(@machine)

        # Force WSL2 communicator usage
        @machine.config.vm.communicator = :wsl2
      end

      # Define action hooks for Vagrant commands
      def action(name)
        return action_up if name == :up
        return action_halt if name == :halt
        return action_destroy if name == :destroy
        return action_ssh if name == :ssh
        return action_ssh_run if name == :ssh_run
        return action_provision if name == :provision
        return action_reload if name == :reload
        return action_snapshot_list if name == :snapshot_list
        return action_snapshot_save if name == :snapshot_save
        return action_snapshot_restore if name == :snapshot_restore
        return action_snapshot_delete if name == :snapshot_delete
        nil
      end

      # Returns the SSH info for accessing the machine
      def ssh_info
        return nil if state.id == :not_created

        # Return special marker to indicate WSL-native connection
        {
          host: "wsl-native",
          username: "vagrant",
          wsl_distribution: @machine.id,
          ready: true
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

      # Define action middleware for 'vagrant up'
      def action_up
        Vagrant::Action::Builder.new.tap do |b|
          b.use Vagrant::Action::Builtin::ConfigValidate
          b.use Vagrant::Action::Builtin::Call, Vagrant::Action::Builtin::IsState, :not_created do |env, b2|
            if env[:result]
              b2.use Action::PrepareEnvironment
              b2.use Action::Create
              b2.use Action::Start
              b2.use Action::ShareFolders
              b2.use Vagrant::Action::Builtin::Provision
            else
              b2.use Action::PrepareEnvironment
              b2.use Vagrant::Action::Builtin::Call, Vagrant::Action::Builtin::IsState, :running do |env2, b3|
                unless env2[:result]
                  b3.use Action::Start
                end
              end
              b2.use Action::ShareFolders
              b2.use Vagrant::Action::Builtin::Provision
            end
          end
        end
      end

      # Define action middleware for 'vagrant halt'
      def action_halt
        Vagrant::Action::Builder.new.tap do |b|
          b.use Vagrant::Action::Builtin::ConfigValidate
          b.use Vagrant::Action::Builtin::Call, Vagrant::Action::Builtin::IsState, :running do |env, b2|
            if env[:result]
              b2.use Action::PrepareEnvironment
              b2.use Action::Halt
            end
          end
        end
      end

      # Define action middleware for 'vagrant destroy'
      def action_destroy
        Vagrant::Action::Builder.new.tap do |b|
          b.use Vagrant::Action::Builtin::ConfigValidate
          b.use Vagrant::Action::Builtin::Call, Vagrant::Action::Builtin::IsState, :not_created do |env, b2|
            unless env[:result]
              b2.use Action::PrepareEnvironment
              b2.use Action::Destroy
            end
          end
        end
      end

      # Define action middleware for 'vagrant ssh'
      def action_ssh
        Vagrant::Action::Builder.new.tap do |b|
          b.use Vagrant::Action::Builtin::ConfigValidate
          b.use Vagrant::Action::Builtin::Call, Vagrant::Action::Builtin::IsState, :running do |env, b2|
            if env[:result]
              b2.use Action::PrepareEnvironment
              b2.use Action::WSLShell
            else
              env[:ui].info("Machine is not running, starting it up...")
              b2.use action_up
              b2.use Action::WSLShell
            end
          end
        end
      end

      # Define action middleware for 'vagrant ssh -c command'
      def action_ssh_run
        Vagrant::Action::Builder.new.tap do |b|
          b.use Vagrant::Action::Builtin::ConfigValidate
          b.use Vagrant::Action::Builtin::Call, Vagrant::Action::Builtin::IsState, :running do |env, b2|
            if env[:result]
              b2.use Action::PrepareEnvironment
              b2.use Action::SSHRun
            else
              env[:ui].info("Machine is not running, starting it up...")
              b2.use action_up
              b2.use Action::SSHRun
            end
          end
        end
      end

      # Define action middleware for 'vagrant provision'
      def action_provision
        Vagrant::Action::Builder.new.tap do |b|
          b.use Vagrant::Action::Builtin::ConfigValidate
          b.use Vagrant::Action::Builtin::Call, Vagrant::Action::Builtin::IsState, :running do |env, b2|
            if env[:result]
              b2.use Action::PrepareEnvironment
              b2.use Action::ShareFolders
              b2.use Vagrant::Action::Builtin::Provision
            else
              env[:ui].info("Machine is not running, starting it up...")
              b2.use action_up
              b2.use Vagrant::Action::Builtin::Provision
            end
          end
        end
      end

      # Define action middleware for 'vagrant reload'
      def action_reload
        Vagrant::Action::Builder.new.tap do |b|
          b.use Vagrant::Action::Builtin::ConfigValidate
          b.use Vagrant::Action::Builtin::Call, Vagrant::Action::Builtin::IsState, :not_created do |env, b2|
            if env[:result]
              env[:ui].info("Machine not created, creating...")
              b2.use action_up
            else
              b2.use Action::PrepareEnvironment
              b2.use Action::Halt
              b2.use Action::Start
            end
          end
        end
      end

      # Define action middleware for 'vagrant snapshot list'
      def action_snapshot_list
        Vagrant::Action::Builder.new.tap do |b|
          b.use Vagrant::Action::Builtin::ConfigValidate
          b.use Action::PrepareEnvironment
          b.use Action::SnapshotList
        end
      end

      # Define action middleware for 'vagrant snapshot save'
      def action_snapshot_save
        Vagrant::Action::Builder.new.tap do |b|
          b.use Vagrant::Action::Builtin::ConfigValidate
          b.use Vagrant::Action::Builtin::Call, Vagrant::Action::Builtin::IsState, :not_created do |env, b2|
            if env[:result]
              raise Vagrant::Errors::VMNotCreatedError
            else
              b2.use Action::PrepareEnvironment
              b2.use Action::SnapshotSave
            end
          end
        end
      end

      # Define action middleware for 'vagrant snapshot restore'
      def action_snapshot_restore
        Vagrant::Action::Builder.new.tap do |b|
          b.use Vagrant::Action::Builtin::ConfigValidate
          b.use Vagrant::Action::Builtin::Call, Vagrant::Action::Builtin::IsState, :not_created do |env, b2|
            if env[:result]
              raise Vagrant::Errors::VMNotCreatedError
            else
              b2.use Action::PrepareEnvironment
              b2.use Action::SnapshotRestore
            end
          end
        end
      end

      # Define action middleware for 'vagrant snapshot delete'
      def action_snapshot_delete
        Vagrant::Action::Builder.new.tap do |b|
          b.use Vagrant::Action::Builtin::ConfigValidate
          b.use Action::PrepareEnvironment
          b.use Action::SnapshotDelete
        end
      end
    end
  end
end

require_relative "driver"