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

      class InstanceReadyTimeout < VagrantAWSError
        error_key(:instance_ready_timeout)
      end

      class RsyncError < VagrantAWSError
        error_key(:rsync_error)
      end

      class ElbDoesNotExistError < VagrantAWSError
        error_key("elb_does_not_exist")
      end
    end
  end
end
