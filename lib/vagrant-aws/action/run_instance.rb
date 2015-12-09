require "log4r"
require 'json'

require 'vagrant/util/retryable'

require 'vagrant-aws/util/timer'

module VagrantPlugins
  module AWS
    module Action
      # This runs the configured instance.
      class RunInstance
        include Vagrant::Util::Retryable

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_aws::action::run_instance")
        end

        def call(env)
          # Initialize metrics if they haven't been
          env[:metrics] ||= {}

          # Get the region we're going to booting up in
          region = env[:machine].provider_config.region

          # Get the configs
          region_config         = env[:machine].provider_config.get_region_config(region)
          ami                   = region_config.ami
          availability_zone     = region_config.availability_zone
          instance_type         = region_config.instance_type
          keypair               = region_config.keypair_name
          private_ip_address    = region_config.private_ip_address
          security_groups       = region_config.security_groups
          subnet_id             = region_config.subnet_id
          tags                  = region_config.tags
          user_data             = region_config.user_data
          block_device_mapping  = region_config.block_device_mapping
          elastic_ip            = region_config.elastic_ip
          terminate_on_shutdown = region_config.terminate_on_shutdown
          iam_instance_profile_arn  = region_config.iam_instance_profile_arn
          iam_instance_profile_name = region_config.iam_instance_profile_name
          monitoring            = region_config.monitoring
          ebs_optimized         = region_config.ebs_optimized
          source_dest_check     = region_config.source_dest_check
          associate_public_ip   = region_config.associate_public_ip
          kernel_id             = region_config.kernel_id
          tenancy               = region_config.tenancy

          # If there is no keypair then warn the user
          if !keypair
            env[:ui].warn(I18n.t("vagrant_aws.launch_no_keypair"))
          end

          # If there is a subnet ID then warn the user
          if subnet_id && !elastic_ip
            env[:ui].warn(I18n.t("vagrant_aws.launch_vpc_warning"))
          end

          # Launch!
          env[:ui].info(I18n.t("vagrant_aws.launching_instance"))
          env[:ui].info(" -- Type: #{instance_type}")
          env[:ui].info(" -- AMI: #{ami}")
          env[:ui].info(" -- Region: #{region}")
          env[:ui].info(" -- Availability Zone: #{availability_zone}") if availability_zone
          env[:ui].info(" -- Keypair: #{keypair}") if keypair
          env[:ui].info(" -- Subnet ID: #{subnet_id}") if subnet_id
          env[:ui].info(" -- IAM Instance Profile ARN: #{iam_instance_profile_arn}") if iam_instance_profile_arn
          env[:ui].info(" -- IAM Instance Profile Name: #{iam_instance_profile_name}") if iam_instance_profile_name
          env[:ui].info(" -- Private IP: #{private_ip_address}") if private_ip_address
          env[:ui].info(" -- Elastic IP: #{elastic_ip}") if elastic_ip
          env[:ui].info(" -- User Data: yes") if user_data
          env[:ui].info(" -- Security Groups: #{security_groups.inspect}") if !security_groups.empty?
          env[:ui].info(" -- User Data: #{user_data}") if user_data
          env[:ui].info(" -- Block Device Mapping: #{block_device_mapping}") if block_device_mapping
          env[:ui].info(" -- Terminate On Shutdown: #{terminate_on_shutdown}")
          env[:ui].info(" -- Monitoring: #{monitoring}")
          env[:ui].info(" -- EBS optimized: #{ebs_optimized}")
          env[:ui].info(" -- Source Destination check: #{source_dest_check}")
          env[:ui].info(" -- Assigning a public IP address in a VPC: #{associate_public_ip}")
          env[:ui].info(" -- VPC tenancy specification: #{tenancy}")

          options = {
            :availability_zone         => availability_zone,
            :flavor_id                 => instance_type,
            :image_id                  => ami,
            :key_name                  => keypair,
            :private_ip_address        => private_ip_address,
            :subnet_id                 => subnet_id,
            :iam_instance_profile_arn  => iam_instance_profile_arn,
            :iam_instance_profile_name => iam_instance_profile_name,
            :tags                      => tags,
            :user_data                 => user_data,
            :block_device_mapping      => block_device_mapping,
            :instance_initiated_shutdown_behavior => terminate_on_shutdown == true ? "terminate" : nil,
            :monitoring                => monitoring,
            :ebs_optimized             => ebs_optimized,
            :associate_public_ip       => associate_public_ip,
            :kernel_id                 => kernel_id,
            :associate_public_ip       => associate_public_ip,
            :tenancy                   => tenancy
          }

          if !security_groups.empty?
            security_group_key = options[:subnet_id].nil? ? :groups : :security_group_ids
            options[security_group_key] = security_groups
            env[:ui].warn(I18n.t("vagrant_aws.warn_ssh_access")) unless allows_ssh_port?(env, security_groups, subnet_id)
          end

          begin
            server = if region_config.spot_instance
                       server_from_spot_request(env, region_config)
                     else
                       env[:aws_compute].servers.create(options)
                     end
            raise Errors::FogError, :message => "server is nil" unless server
          rescue Fog::Compute::AWS::NotFound => e
            # Invalid subnet doesn't have its own error so we catch and
            # check the error message here.
            if e.message =~ /subnet ID/
              raise Errors::FogError,
                :message => "Subnet ID not found: #{subnet_id}"
            end

            raise
          rescue Fog::Compute::AWS::Error => e
            raise Errors::FogError, :message => e.message
          rescue Excon::Errors::HTTPStatusError => e
            raise Errors::InternalFogError,
              :error => e.message,
              :response => e.response.body
          end

          # Immediately save the ID since it is created at this point.
          env[:machine].id = server.id

	  # Spot Instances don't support tagging arguments on creation
	  # Retrospectively tag the server to handle this
	  env[:aws_compute].create_tags(server.id,tags)
		  
          # Wait for the instance to be ready first
          env[:metrics]["instance_ready_time"] = Util::Timer.time do
            tries = region_config.instance_ready_timeout / 2

            env[:ui].info(I18n.t("vagrant_aws.waiting_for_ready"))
            begin
              retryable(:on => Fog::Errors::TimeoutError, :tries => tries) do
                # If we're interrupted don't worry about waiting
                next if env[:interrupted]

                # Wait for the server to be ready
                server.wait_for(2, region_config.instance_check_interval) { ready? }
              end
            rescue Fog::Errors::TimeoutError
              # Delete the instance
              terminate(env)

              # Notify the user
              raise Errors::InstanceReadyTimeout,
                timeout: region_config.instance_ready_timeout
            end
          end

          @logger.info("Time to instance ready: #{env[:metrics]["instance_ready_time"]}")

          # Allocate and associate an elastic IP if requested
          if elastic_ip
            domain = subnet_id ? 'vpc' : 'standard'
            do_elastic_ip(env, domain, server, elastic_ip)
          end

          # Set the source destination checks
          if !source_dest_check.nil?
            if server.vpc_id.nil?
                env[:ui].warn(I18n.t("vagrant_aws.source_dest_checks_no_vpc"))
            else
                begin
                    attrs = {
                        "SourceDestCheck.Value" => source_dest_check
                    }
                    env[:aws_compute].modify_instance_attribute(server.id, attrs)
                rescue Fog::Compute::AWS::Error => e
                    raise Errors::FogError, :message => e.message
                end
            end
        end

          if !env[:interrupted]
            env[:metrics]["instance_ssh_time"] = Util::Timer.time do
              # Wait for SSH to be ready.
              env[:ui].info(I18n.t("vagrant_aws.waiting_for_ssh"))
              network_ready_retries = 0
              network_ready_retries_max = 10
              while true
                # If we're interrupted then just back out
                break if env[:interrupted]
                # When an ec2 instance comes up, it's networking may not be ready
                # by the time we connect.
                begin
                  break if env[:machine].communicate.ready?
                rescue Exception => e
                  if network_ready_retries < network_ready_retries_max then
                    network_ready_retries += 1
                    @logger.warn(I18n.t("vagrant_aws.waiting_for_ssh, retrying"))
                  else
                    raise e
                  end
                end
                sleep 2
              end
            end

            @logger.info("Time for SSH ready: #{env[:metrics]["instance_ssh_time"]}")

            # Ready and booted!
            env[:ui].info(I18n.t("vagrant_aws.ready"))
          end

          # Terminate the instance if we were interrupted
          terminate(env) if env[:interrupted]

          @app.call(env)
        end

        # returns a fog server or nil
        def server_from_spot_request(env, config)
          # prepare request args
          options = {
            'InstanceCount'                                  => 1,
            'LaunchSpecification.KeyName'                    => config.keypair_name,
            'LaunchSpecification.Placement.AvailabilityZone' => config.availability_zone,
            'LaunchSpecification.UserData'                   => config.user_data,
            'LaunchSpecification.SubnetId'                   => config.subnet_id,
			'LaunchSpecification.BlockDeviceMapping'		 => config.block_device_mapping,
            'ValidUntil'                                     => config.spot_valid_until
          }
          security_group_key = config.subnet_id.nil? ? 'LaunchSpecification.SecurityGroup' : 'LaunchSpecification.SecurityGroupId'
          options[security_group_key] = config.security_groups
          options.delete_if { |key, value| value.nil? }

          env[:ui].info(I18n.t("vagrant_aws.launching_spot_instance"))
          env[:ui].info(" -- Price: #{config.spot_max_price}")
          env[:ui].info(" -- Valid until: #{config.spot_valid_until}") if config.spot_valid_until
          env[:ui].info(" -- Monitoring: #{config.monitoring}") if config.monitoring

          # create the spot instance
          spot_req = env[:aws_compute].request_spot_instances(
            config.ami,
            config.instance_type,
            config.spot_max_price,
            options).body["spotInstanceRequestSet"].first

          spot_request_id = spot_req["spotInstanceRequestId"]
          @logger.info("Spot request ID: #{spot_request_id}")

          # initialize state
          status_code = ""
          while true
            sleep 5 # TODO make it a param

            raise Errors::FogError, :message => "Interrupted" if env[:interrupted]
            spot_req = env[:aws_compute].describe_spot_instance_requests(
              'spot-instance-request-id' => [spot_request_id]).body["spotInstanceRequestSet"].first

            # waiting for spot request ready
            next unless spot_req

            # display something whenever the status code changes
            if status_code != spot_req["state"]
              env[:ui].info(spot_req["fault"]["message"])
              status_code = spot_req["state"]
            end
            spot_state = spot_req["state"].to_sym
            case spot_state
            when :not_created, :open
              @logger.debug("Spot request #{spot_state} #{status_code}, waiting")
            when :active
              break; # :)
            when :closed, :cancelled, :failed
              msg = "Spot request #{spot_state} #{status_code}, aborting"
              @logger.error(msg)
              raise Errors::FogError, :message => msg
            else
              @logger.debug("Unknown spot state #{spot_state} #{status_code}, waiting")
            end
          end
          # cancel the spot request but let the server go thru
          env[:aws_compute].cancel_spot_instance_requests(spot_request_id)
          server = env[:aws_compute].servers.get(spot_req["instanceId"])
          env[:aws_compute].create_tags(server.identity, config.tags)
          server
        end

        def recover(env)
          return if env["vagrant.error"].is_a?(Vagrant::Errors::VagrantError)

          if env[:machine].provider.state.id != :not_created
            # Undo the import
            terminate(env)
          end
        end

        def allows_ssh_port?(env, test_sec_groups, is_vpc)
          port = 22 # TODO get ssh_info port
          test_sec_groups = [ "default" ] if test_sec_groups.empty? # AWS default security group
          # filter groups by name or group_id (vpc)
          groups = test_sec_groups.map do |tsg|
            env[:aws_compute].security_groups.all.select { |sg| tsg == (is_vpc ? sg.group_id : sg.name) }
          end.flatten
          # filter TCP rules
          rules = groups.map { |sg| sg.ip_permissions.select { |r| r["ipProtocol"] == "tcp" } }.flatten
          # test if any range includes port
          !rules.select { |r| (r["fromPort"]..r["toPort"]).include?(port) }.empty?
        end

        def do_elastic_ip(env, domain, server, elastic_ip)
          if elastic_ip =~ /\d+\.\d+\.\d+\.\d+/
            begin
              address = env[:aws_compute].addresses.get(elastic_ip)
            rescue
              handle_elastic_ip_error(env, "Could not retrieve Elastic IP: #{elastic_ip}")
            end
            if address.nil?
              handle_elastic_ip_error(env, "Elastic IP not available: #{elastic_ip}")
            end
            @logger.debug("Public IP #{address.public_ip}")
          else
            begin
              allocation = env[:aws_compute].allocate_address(domain)
            rescue
              handle_elastic_ip_error(env, "Could not allocate Elastic IP.")
            end
            @logger.debug("Public IP #{allocation.body['publicIp']}")
          end

          # Associate the address and save the metadata to a hash
          h = nil
          if domain == 'vpc'
            # VPC requires an allocation ID to assign an IP
            if address
              association = env[:aws_compute].associate_address(server.id, nil, nil, address.allocation_id)
            else
              association = env[:aws_compute].associate_address(server.id, nil, nil, allocation.body['allocationId'])
              # Only store release data for an allocated address
              h = { :allocation_id => allocation.body['allocationId'], :association_id => association.body['associationId'], :public_ip => allocation.body['publicIp'] }
            end
          else
            # Standard EC2 instances only need the allocated IP address
            if address
              association = env[:aws_compute].associate_address(server.id, address.public_ip)
            else
              association = env[:aws_compute].associate_address(server.id, allocation.body['publicIp'])
              h = { :public_ip => allocation.body['publicIp'] }
            end
          end

          unless association.body['return']
            @logger.debug("Could not associate Elastic IP.")
            terminate(env)
            raise Errors::FogError,
                            :message => "Could not allocate Elastic IP."
          end

          # Save this IP to the data dir so it can be released when the instance is destroyed
          if h 
            ip_file = env[:machine].data_dir.join('elastic_ip')
            ip_file.open('w+') do |f|
              f.write(h.to_json)
            end
          end
        end

        def handle_elastic_ip_error(env, message) 
          @logger.debug(message)
          terminate(env)
          raise Errors::FogError,
                          :message => message
        end

        def terminate(env)
          destroy_env = env.dup
          destroy_env.delete(:interrupted)
          destroy_env[:config_validate] = false
          destroy_env[:force_confirm_destroy] = true
          env[:action_runner].run(Action.action_destroy, destroy_env)
        end
      end
    end
  end
end
