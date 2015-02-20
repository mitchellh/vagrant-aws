require 'vagrant-aws/util/network_adapters'

module VagrantPlugins
  module AWS
    module Action      
      class DestroyAdditionalNetworkInterfaces
        include NetworkAdapter

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_aws::action::network_adapters_register")
        end

        def call(env)

          interfaces = env[:machine].provider_config.additional_network_interfaces

          interfaces.each do |intf|
            env[:ui].info(I18n.t("vagrant_aws.destroy_network_interface"))
            env[:ui].info(" -- Device Index: #{intf[:device_index]}")            
            env[:ui].info(" -- Attached To: #{env[:machine].id}")   
          	destroy_adapter env, intf[:device_index], env[:machine].id
          end            

          @app.call(env)
          
        end
      end
    end
  end
end