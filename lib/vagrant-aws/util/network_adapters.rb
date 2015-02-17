module VagrantPlugins
  module AWS
    module NetworkAdapter

      def register_adapter(env, device_index, subnet_id, security_groups, private_ip_address, instance_id)       
		
		if private_ip_address.nil?
			interface = env[:aws_compute].network_interfaces.create(:subnet_id => subnet_id, :group_set => security_groups )
		else
			interface = env[:aws_compute].network_interfaces.create(:subnet_id => subnet_id, :group_set => security_groups, :private_ip_address => private_ip_address )
		end
		
		env[:aws_compute].attach_network_interface(interface.network_interface_id, instance_id, device_index)
      end

      def destroy_adapter(env, device_index, instance_id)       
		interface = env[:aws_compute].network_interfaces.all('attachment.instance-id' => instance_id, 'attachment.device-index' => device_index ).first
		
		if interface.nil?
			return
		end

		if !interface.attachment.nil? && interface.attachment != {} 
			env[:aws_compute].detach_network_interface(interface.attachment['attachmentId'], true)
			interface.wait_for { attachment.nil? || attachment == {} }
		end
		
		interface.destroy
      end     
     
    end
  end
end