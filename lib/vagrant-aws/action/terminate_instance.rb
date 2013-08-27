require "log4r"

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
          server = env[:aws_compute].servers.get(env[:machine].id)

          # Destroy the server and remove the tracking ID
          env[:ui].info(I18n.t("vagrant_aws.terminating"))
          server.destroy
          # Deallocate Elastic IP if allocated
          elastic_ip = env[:aws_compute].describe_addresses('public-ip' => server.public_ip_address)
          env[:aws_compute].disassociate_address(nil,elastic_ip[:body]["addressesSet"][0]["associationId"]) if !elastic_ip[:body]["addressesSet"].empty?
          env[:ui].info(I18n.t("vagrant_aws.elastic_ip_deallocated"))
          env[:machine].id = nil

          @app.call(env)
        end
      end
    end
  end
end
