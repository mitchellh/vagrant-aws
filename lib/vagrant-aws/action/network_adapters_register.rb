require 'vagrant-aws/util/network_adapters'

module VagrantPlugins
  module AWS
    module Action      
      class RegisterAdditionalNetworkInterfaces
        include ElasticLoadBalancer

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_aws::action::network_adapters_register")
        end

        def call(env)

          @app.call(env)

          interfaces = env[:machine].provider_config.additional_network_interfaces

          interfaces.each do |intf|
          	register_adapter env, intf[:device_index], intf[:subnet_id], intf[:security_groups], env[:machine].id
          end            
          
        end
      end
    end
  end
end
