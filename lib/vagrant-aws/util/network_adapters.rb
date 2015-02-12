module VagrantPlugins
  module AWS
    module NetworkAdapter

      def register_adapter(env, device_index, subnet_id, security_groups, instance_id)       
		interface = env[:aws_compute].network_interfaces.create(:subnet_id => subnet_id, :group_set => security_groups )
		ec2.attach_network_interface(interface.network_interface_id, instance_id, device_index)
      end
     
    end
  end
end
