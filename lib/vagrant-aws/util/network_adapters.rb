module VagrantPlugins
  module AWS
    module NetworkAdapter

		def ip_attributes(ips)
			return {} if ips.nil?

			attrs = { 'PrivateIpAddresses.0.Primary' => true }

			if ips.kind_of?(Array)
				ips.each_with_index do |ip, i|
					attrs["PrivateIpAddresses.#{i}.PrivateIpAddress"] = ip
				end
			else
				attrs["PrivateIpAddresses.0.PrivateIpAddress"] = ips
			end

			attrs
		end

		def security_group_attributes(security_groups)
			attrs = {}

			if security_groups.kind_of?(Array)
			security_groups.each_with_index do |sid, i|
				attrs["SecurityGroupId.#{i + 1}"] = sid
			end
			else
			attrs["SecurityGroupId.1"] = security_groups
			end

			attrs
		end

      def register_adapter(env, device_index, subnet_id, security_groups, private_ip_address, instance_id)       
		
		options = {}
		options.merge security_group_attributes(security_groups)
		options.merge ip_attributes(private_ip_address)

		interface = env[:aws_compute].create_network_interface(
			subnet_id,
			options
		)
		
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