require "log4r"
require "json"

module VagrantPlugins
  module AWS
    module Action
      # This terminates the running instance.
      class TerminateInstance
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_aws::action::terminate_instance")
        end

        def call(env)
          server         = env[:aws_compute].servers.get(env[:machine].id)
          region         = env[:machine].provider_config.region
          region_config  = env[:machine].provider_config.get_region_config(region)

          elastic_ip     = region_config.elastic_ip

          # Release the elastic IP
          ip_file = env[:machine].data_dir.join('elastic_ip')
          if ip_file.file?
            release_address(env,ip_file.read)
            ip_file.delete
          end

          # Destroy the server and remove the tracking ID
          env[:ui].info(I18n.t("vagrant_aws.terminating"))
          server.destroy
          env[:machine].id = nil

          @app.call(env)
        end

        # Release an elastic IP address
        def release_address(env,eip)
          h = JSON.parse(eip)
          # Use association_id and allocation_id for VPC, use public IP for EC2
          if h['association_id']
            env[:aws_compute].disassociate_address(nil,h['association_id'])
            env[:aws_compute].release_address(h['allocation_id'])
          else
            env[:aws_compute].disassociate_address(h['public_ip'])
            env[:aws_compute].release_address(h['public_ip'])
          end
        end
      end
    end
  end
end
