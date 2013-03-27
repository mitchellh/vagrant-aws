require "log4r"

module VagrantPlugins
  module AWS
    module Action
      # This action reads the SSH info for the machine and puts it into the
      # `:machine_ssh_info` key in the environment.
      class ReadSSHInfo
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_aws::action::read_ssh_info")
        end

        def call(env)
          env[:machine_ssh_info] = read_ssh_info(env[:aws_compute], env[:machine])

          @app.call(env)
        end

        def read_ssh_info(aws, machine)
          return nil if machine.id.nil?

          # Find the machine
          server = aws.servers.get(machine.id)
          if server.nil?
            # The machine can't be found
            @logger.info("Machine couldn't be found, assuming it got destroyed.")
            machine.id = nil
            return nil
          end

          # Get the configuration
          region = machine.provider_config.region
          config = machine.provider_config.get_region_config(region)

          # Read the DNS info
          return {
            :host => server.private_ip_address.nil? ? server.dns_name : server.private_ip_address,
            :port => config.ssh_port,
            :private_key_path => config.ssh_private_key_path,
            :username => config.ssh_username
          }
        end
      end
    end
  end
end
