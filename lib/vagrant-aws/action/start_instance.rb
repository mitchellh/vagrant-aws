require "log4r"

require 'vagrant/util/retryable'

require 'vagrant-aws/util/timer'

module VagrantPlugins
  module AWS
    module Action
      # This starts a stopped instance.
      class StartInstance
        include Vagrant::Util::Retryable

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_aws::action::start_instance")
        end

        def call(env)
          # Initialize metrics if they haven't been
          env[:metrics] ||= {}

          server = env[:aws_compute].servers.get(env[:machine].id)

          env[:ui].info(I18n.t("vagrant_aws.starting"))

          begin
            server.start

            # Wait for the instance to be ready first
            env[:metrics]["instance_ready_time"] = Util::Timer.time do
              env[:ui].info(I18n.t("vagrant_aws.waiting_for_ready"))
              retryable(:on => Fog::Errors::TimeoutError, :tries => 30) do
                # If we're interrupted don't worry about waiting
                next if env[:interrupted]

                # Wait for the server to be ready
                server.wait_for(2) { ready? }
              end
            end
          rescue Fog::Compute::AWS::Error => e
            raise Errors::FogError, :message => e.message
          end

          @logger.info("Time to instance ready: #{env[:metrics]["instance_ready_time"]}")

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

          @app.call(env)
        end
      end
    end
  end
end
