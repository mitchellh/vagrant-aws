require 'vagrant-aws/util/network_adapters'

module VagrantPlugins
  module AWS
    module Action      
      class RegisterAdditionalNetworkInterfaces
        include NetworkAdapter

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_aws::action::network_adapters_register")
        end

        def call(env)

          @app.call(env)

          interfaces = env[:machine].provider_config.additional_network_interfaces

          interfaces.each do |intf|
            env[:ui].info(I18n.t("vagrant_aws.creating_network_interface"))
            env[:ui].info(" -- Device Index: #{intf[:device_index]}")
            env[:ui].info(" -- Subnet ID: #{intf[:subnet_id]}")
            env[:ui].info(" -- Security Groups: #{intf[:security_groups]}")
            env[:ui].info(" -- IP: #{intf[:private_ip_address]}")
          	register_adapter env, intf[:device_index], intf[:subnet_id], intf[:security_groups], intf[:private_ip_address], env[:machine].id
          end            
          
        end
      end
    end
  end
end