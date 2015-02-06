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

          # read attribute override
          ssh_host_attribute = machine.provider_config.
              get_region_config(machine.provider_config.region).ssh_host_attribute
          # default host attributes to try. NOTE: Order matters!
          ssh_attrs = [:dns_name, :public_ip_address, :private_ip_address]
          ssh_attrs = (Array(ssh_host_attribute) + ssh_attrs).uniq if ssh_host_attribute
          # try each attribute, get out on first value
          host_value = nil
          while !host_value and attr_name = ssh_attrs.shift
            begin
              host_value = server.send(attr_name)
            rescue NoMethodError
              @logger.info("SSH host attribute not found #{attr_name}")
            end
          end

          return { :host => host_value, :port => 22 }
        end
      end
    end
  end
end
