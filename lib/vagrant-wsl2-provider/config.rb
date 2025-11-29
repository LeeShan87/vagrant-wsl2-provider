require "vagrant"

module VagrantPlugins
  module WSL2
    class WslConf
      def initialize
        @config = {}
      end

      def method_missing(method, *args)
        if method.to_s.end_with?('=')
          key = method.to_s.chop.to_sym
          @config[key] = args.first
        else
          @config[method] ||= WslConf.new
        end
      end

      def to_h
        result = {}
        @config.each do |key, value|
          result[key] = value.is_a?(WslConf) ? value.to_h : value
        end
        result
      end
    end

    class DataDiskConfig
      attr_accessor :path
      attr_accessor :size        # Size in GB (only for new VHD creation)
      attr_accessor :format      # 'vhd' or 'vhdx'
      attr_accessor :mount_point # Where to mount in WSL (e.g., '/mnt/data')

      def initialize
        @path = nil
        @size = nil
        @format = 'vhdx'
        @mount_point = nil
      end

      def validate
        errors = []

        # Either path or size must be specified
        if @path.nil? && @size.nil?
          errors << "Data disk must have either 'path' (existing VHD) or 'size' (create new VHD)"
        end

        # Validate format
        if @format && !['vhd', 'vhdx'].include?(@format.downcase)
          errors << "Data disk format must be 'vhd' or 'vhdx'"
        end

        # Validate path extension if provided
        if @path && !['.vhd', '.vhdx'].include?(File.extname(@path).downcase)
          errors << "Data disk path must end with .vhd or .vhdx"
        end

        # Validate size if provided
        if @size && (@size < 1 || @size > 16384)
          errors << "Data disk size must be between 1GB and 16TB (16384GB)"
        end

        errors
      end
    end

    class Config < Vagrant.plugin("2", :config)
      # WSL2 distribution name
      attr_accessor :distribution_name

      # Alias for distribution_name for convenience
      alias_method :name, :distribution_name
      alias_method :name=, :distribution_name=

      # WSL2 version (1 or 2)
      attr_accessor :version

      # Memory limit in MB
      attr_accessor :memory

      # CPU count
      attr_accessor :cpus

      # Custom kernel parameters
      attr_accessor :kernel_command_line

      # Swap size in MB
      attr_accessor :swap

      # Enable GUI support (WSLg)
      attr_accessor :gui_support

      # Data disks configuration
      attr_reader :data_disks

      # wsl.conf configuration
      attr_reader :wsl_conf

      # Aliases for common wsl.conf settings
      def systemd=(value)
        @wsl_conf.boot.systemd = value
      end

      def systemd
        @wsl_conf.boot.systemd
      end

      def boot_command=(value)
        @wsl_conf.boot.command = value
      end

      def boot_command
        @wsl_conf.boot.command
      end

      def hostname=(value)
        @wsl_conf.network.hostname = value
      end

      def hostname
        @wsl_conf.network.hostname
      end

      def default_user=(value)
        @wsl_conf.user.default = value
      end

      def default_user
        @wsl_conf.user.default
      end

      # Define a data disk configuration
      def data_disk(&block)
        @data_disks ||= []
        disk = DataDiskConfig.new
        disk.instance_eval(&block) if block_given?
        @data_disks << disk
        disk
      end

      def initialize
        @distribution_name = UNSET_VALUE
        @version = UNSET_VALUE
        @memory = UNSET_VALUE
        @cpus = UNSET_VALUE
        @kernel_command_line = UNSET_VALUE
        @swap = UNSET_VALUE
        @gui_support = UNSET_VALUE
        @data_disks = []
        @wsl_conf = WslConf.new
      end

      def finalize!
        # Default distribution_name will be set to nil and generated during Create action
        # This prevents generating a new random name on every command
        @distribution_name = nil if @distribution_name == UNSET_VALUE
        @version = 2 if @version == UNSET_VALUE
        @memory = 4096 if @memory == UNSET_VALUE
        @cpus = 2 if @cpus == UNSET_VALUE
        @kernel_command_line = "" if @kernel_command_line == UNSET_VALUE
        @swap = 1024 if @swap == UNSET_VALUE
        @gui_support = false if @gui_support == UNSET_VALUE
      end

      def validate(machine)
        errors = _detected_errors

        # Validate distribution name (skip if nil, will be auto-generated)
        if @distribution_name && @distribution_name.to_s.strip.empty?
          errors << "Distribution name cannot be empty"
        end

        # Validate WSL version
        unless [1, 2].include?(@version)
          errors << "WSL version must be 1 or 2"
        end

        # Validate memory
        if @memory && (@memory < 512 || @memory > 32768)
          errors << "Memory must be between 512MB and 32GB"
        end

        # Validate CPU count
        if @cpus && (@cpus < 1 || @cpus > 32)
          errors << "CPU count must be between 1 and 32"
        end

        # Validate data disks
        if @data_disks && @data_disks.any?
          @data_disks.each_with_index do |disk, index|
            disk_errors = disk.validate
            disk_errors.each do |error|
              errors << "Data disk #{index + 1}: #{error}"
            end
          end
        end

        { "WSL2 Provider" => errors }
      end
    end
  end
end