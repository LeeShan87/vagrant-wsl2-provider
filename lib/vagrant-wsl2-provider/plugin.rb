require "vagrant"

module VagrantPlugins
  module WSL2
    def self.source_root
      @source_root ||= Pathname.new(File.expand_path("../../", __FILE__))
    end

    class Plugin < Vagrant.plugin("2")
      name "WSL2 Provider"
      description "Vagrant provider plugin for managing WSL2 distributions"

      # Load locales
      def self.setup_i18n
        locale_path = File.expand_path("../../../locales/en/vagrant_wsl2.yml", __FILE__)
        I18n.load_path << locale_path if File.exist?(locale_path)
        I18n.reload!
      end

      provider "wsl2" do
        setup_i18n
        require_relative "provider"
        Provider
      end

      config "wsl2", :provider do
        require_relative "config"
        Config
      end

      communicator "wsl2" do
        require_relative "communicator"
        Communicator
      end

      # Universal guest capability for shell path expansion
      guest_capability "linux", "shell_expand_guest_path" do
        require_relative "cap/shell_expand_guest_path"
        Cap::ShellExpandGuestPath
      end

      # Provider capabilities
      provider_capability "wsl2", "snapshot_list" do
        require_relative "cap/snapshot_list"
        Cap::SnapshotList
      end

      provider_capability "wsl2", "snapshot_save" do
        require_relative "cap/snapshot_save"
        Cap::SnapshotSave
      end

      provider_capability "wsl2", "snapshot_restore" do
        require_relative "cap/snapshot_restore"
        Cap::SnapshotRestore
      end

      provider_capability "wsl2", "snapshot_delete" do
        require_relative "cap/snapshot_delete"
        Cap::SnapshotDelete
      end
    end
  end
end