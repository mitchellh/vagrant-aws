require "vagrant/action/builder"

module VagrantPlugins
  module AWS
    module Capability
      class WinRMInfo
        def self.winrm_info(machine)
          machine.action("get_winrm_password")
          return {}
        end        
      end
    end
  end
end
