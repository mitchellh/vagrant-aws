require "vagrant"

module VagrantPlugins
  module AWS
    module Errors
      class VagrantAWSError < Vagrant::Errors::VagrantError
        error_namespace("vagrant_aws.errors")
      end

      class FogError < VagrantAWSError
        error_key(:fog_error)
      end

      class RsyncError < VagrantAWSError
        error_key(:rsync_error)
      end
    end
  end
end
