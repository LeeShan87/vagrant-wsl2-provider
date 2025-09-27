require "vagrant"

module VagrantPlugins
  module WSL2
    module Errors
      class WSL2Error < Vagrant::Errors::VagrantError
        error_namespace("vagrant_wsl2.errors")
      end

      class WindowsRequired < WSL2Error
        error_key(:windows_required)
      end

      class WSLNotInstalled < WSL2Error
        error_key(:wsl_not_installed)
      end

      class WSLCommandFailed < WSL2Error
        error_key(:wsl_command_failed)
      end

      class DistributionNotFound < WSL2Error
        error_key(:distribution_not_found)
      end

      class DistributionAlreadyExists < WSL2Error
        error_key(:distribution_already_exists)
      end
    end
  end
end