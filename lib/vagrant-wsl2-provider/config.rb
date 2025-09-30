require "vagrant"

module VagrantPlugins
  module WSL2
    class Config < Vagrant.plugin("2", :config)
      # WSL2 distribution name
      attr_accessor :distribution_name

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

      def initialize
        @distribution_name = UNSET_VALUE
        @version = UNSET_VALUE
        @memory = UNSET_VALUE
        @cpus = UNSET_VALUE
        @kernel_command_line = UNSET_VALUE
        @swap = UNSET_VALUE
        @gui_support = UNSET_VALUE
      end

      def finalize!
        @distribution_name = "vagrant-#{Time.now.to_i}" if @distribution_name == UNSET_VALUE
        @version = 2 if @version == UNSET_VALUE
        @memory = 4096 if @memory == UNSET_VALUE
        @cpus = 2 if @cpus == UNSET_VALUE
        @kernel_command_line = "" if @kernel_command_line == UNSET_VALUE
        @swap = 1024 if @swap == UNSET_VALUE
        @gui_support = false if @gui_support == UNSET_VALUE
      end

      def validate(machine)
        errors = _detected_errors

        # Validate distribution name
        if @distribution_name.to_s.strip.empty?
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

        { "WSL2 Provider" => errors }
      end
    end
  end
end