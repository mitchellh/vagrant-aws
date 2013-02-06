require "log4r"

require 'vagrant/util/retryable'

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
          region       = env[:machine].provider_config.region

          # Get the configs
          region_config      = env[:machine].provider_config.get_region_config(region)
          ami                = region_config.ami
          instance_type      = region_config.instance_type
          keypair            = region_config.keypair_name
          private_ip_address = region_config.private_ip_address
          subnet_id          = region_config.subnet_id

          # If there is no keypair then warn the user
          if !keypair
            env[:ui].warn(I18n.t("vagrant_aws.launch_no_keypair"))
          end

          # If there is a subnet ID then warn the user
          if subnet_id
            env[:ui].warn(I18n.t("vagrant_aws.launch_vpc_warning"))
          end

          # Launch!
          env[:ui].info(I18n.t("vagrant_aws.launching_instance"))
          env[:ui].info(" -- Type: #{instance_type}")
          env[:ui].info(" -- AMI: #{ami}")
          env[:ui].info(" -- Region: #{region}")
          env[:ui].info(" -- Keypair: #{keypair}") if keypair
          env[:ui].info(" -- Subnet ID: #{subnet_id}") if subnet_id
          env[:ui].info(" -- Private IP: #{private_ip_address}") if private_ip_address

          begin
            server = env[:aws_compute].servers.create({
              :flavor_id          => instance_type,
              :image_id           => ami,
              :key_name           => keypair,
              :private_ip_address => private_ip_address,
              :subnet_id          => subnet_id
            })
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
          end

          # Immediately save the ID since it is created at this point.
          env[:machine].id = server.id

          # Wait for the instance to be ready first
          env[:ui].info(I18n.t("vagrant_aws.waiting_for_ready"))
          retryable(:on => Fog::Errors::TimeoutError, :tries => 30) do
            # If we're interrupted don't worry about waiting
            next if env[:interrupted]

            # Wait for the server to be ready
            server.wait_for(2) { ready? }
          end

          if !env[:interrupted]
            # Wait for SSH to be ready.
            env[:ui].info(I18n.t("vagrant_aws.waiting_for_ssh"))
            while true
              # If we're interrupted then just back out
              break if env[:interrupted]
              break if env[:machine].communicate.ready?
              sleep 2
            end

            # Ready and booted!
            env[:ui].info(I18n.t("vagrant_aws.ready"))
          end

          # Terminate the instance if we were interrupted
          terminate(env) if env[:interrupted]

          @app.call(env)
        end

        def recover(env)
          return if env["vagrant.error"].is_a?(Vagrant::Errors::VagrantError)

          if env[:machine].provider.state.id != :not_created
            # Undo the import
            terminate(env)
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
