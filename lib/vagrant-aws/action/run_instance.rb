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
            :ebs_optimized             => ebs_optimized
          }
          if !security_groups.empty?
            security_group_key = options[:subnet_id].nil? ? :groups : :security_group_ids
            options[security_group_key] = security_groups
          end

          begin
            env[:ui].warn(I18n.t("vagrant_aws.warn_ssh_access")) unless allows_ssh_port?(env, security_groups, subnet_id)

            if region_config.spot_instance
              server = server_from_spot_request(env, region_config)
            else
              server = env[:aws_compute].servers.create(options)
            end
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

          # Wait for the instance to be ready first
          env[:metrics]["instance_ready_time"] = Util::Timer.time do
            tries = region_config.instance_ready_timeout / 2

            env[:ui].info(I18n.t("vagrant_aws.waiting_for_ready"))
            begin
              retryable(:on => Fog::Errors::TimeoutError, :tries => tries) do
                # If we're interrupted don't worry about waiting
                next if env[:interrupted]

                # Wait for the server to be ready
                server.wait_for(2) { ready? }
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
            do_elastic_ip(env, domain, server)
          end

          if !env[:interrupted]
            env[:metrics]["instance_ssh_time"] = Util::Timer.time do
              # Wait for SSH to be ready.
              env[:ui].info(I18n.t("vagrant_aws.waiting_for_ssh"))
              while true
                # If we're interrupted then just back out
                break if env[:interrupted]
                break if env[:machine].communicate.ready?
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

        def server_from_spot_request(env, config)
          # prepare request args. TODO map all options OR use a different API to launch
          options = {
            'InstanceCount'                                  => 1,
            'LaunchSpecification.KeyName'                    => config.keypair_name,
            'LaunchSpecification.Monitoring.Enabled'         => config.monitoring,
            'LaunchSpecification.Placement.AvailabilityZone' => config.availability_zone,
            'LaunchSpecification.EbsOptimized'               => config.ebs_optimized,
            'LaunchSpecification.UserData'                   => config.user_data,
            'LaunchSpecification.SubnetId'                   => config.subnet_id,
            'ValidUntil'                                     => config.spot_valid_until
          }
          security_group_key = config.subnet_id.nil? ? 'LaunchSpecification.SecurityGroup' : 'LaunchSpecification.SecurityGroupId'
          options[security_group_key] = config.security_groups
          options.delete_if { |key, value| value.nil? }

          env[:ui].info(I18n.t("vagrant_aws.launching_spot_instance"))
          env[:ui].info(" -- Price: #{config.spot_max_price}")
          env[:ui].info(" -- Valid until: #{config.spot_valid_until}") if config.spot_valid_until

          # create the spot instance
          spot_req = env[:aws_compute].request_spot_instances(
            config.ami,
            config.instance_type,
            config.spot_max_price,
            options).body["spotInstanceRequestSet"].first

          spot_request_id = spot_req["spotInstanceRequestId"]
          @logger.info("Spot request ID: #{spot_request_id}")
          env[:ui].info("Status: #{spot_req["fault"]["message"]}")
          status_code = spot_req["fault"]["code"] # fog uses "fault" instead of "status"
          while true
            sleep 5 # TODO make it a param
            break if env[:interrupted]
            spot_req = env[:aws_compute].describe_spot_instance_requests(
              'spot-instance-request-id' => [spot_request_id]).body["spotInstanceRequestSet"].first
            next if spot_req.nil? # are we too fast?
            # display something whenever the status code changes
            if status_code != spot_req["fault"]["code"]
              env[:ui].info("Status: #{spot_req["fault"]["message"]}")
              status_code = spot_req["fault"]["code"]
            end
            spot_state = spot_req["state"].to_sym
            case spot_state
            when :not_created, :open
              @logger.debug("Spot request #{spot_state} #{status_code}, waiting")
            when :active
              break; # :)
            when :closed, :cancelled, :failed
              @logger.error("Spot request #{spot_state} #{status_code}, aborting")
              break; # :(
            else
              @logger.debug("Unknown spot state #{spot_state} #{status_code}, waiting")
            end
          end
          # cancel the spot request but let the server go thru
          env[:aws_compute].cancel_spot_instance_requests(spot_request_id)
          # tries to return a server
          spot_req["instanceId"] ? env[:aws_compute].servers.get(spot_req["instanceId"]) : nil
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

        def do_elastic_ip(env, domain, server)
          begin
            allocation = env[:aws_compute].allocate_address(domain)
          rescue
            @logger.debug("Could not allocate Elastic IP.")
            terminate(env)
            raise Errors::FogError,
                            :message => "Could not allocate Elastic IP."
          end
          @logger.debug("Public IP #{allocation.body['publicIp']}")

          # Associate the address and save the metadata to a hash
          if domain == 'vpc'
            # VPC requires an allocation ID to assign an IP
            association = env[:aws_compute].associate_address(server.id, nil, nil, allocation.body['allocationId'])
            h = { :allocation_id => allocation.body['allocationId'], :association_id => association.body['associationId'], :public_ip => allocation.body['publicIp'] }
          else
            # Standard EC2 instances only need the allocated IP address
            association = env[:aws_compute].associate_address(server.id, allocation.body['publicIp'])
            h = { :public_ip => allocation.body['publicIp'] }
          end

          unless association.body['return']
            @logger.debug("Could not associate Elastic IP.")
            terminate(env)
            raise Errors::FogError,
                            :message => "Could not allocate Elastic IP."
          end

          # Save this IP to the data dir so it can be released when the instance is destroyed
          ip_file = env[:machine].data_dir.join('elastic_ip')
          ip_file.open('w+') do |f|
            f.write(h.to_json)
          end
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
