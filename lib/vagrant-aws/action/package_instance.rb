require "log4r"

require 'vagrant-aws/util/timer'

module VagrantPlugins
  module AWS
    module Action
      # This packges the running instance.
      class PackageInstance
        include Vagrant::Util::Retryable

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_aws::action::stop_instance")
        end

        def call(env)
          # Initialize metrics if they haven't been
          env[:metrics] ||= {}

          server = env[:aws_compute].servers.get(env[:machine].id)

          if env[:machine].state.id == :stopped
            env[:ui].info(I18n.t("vagrant_aws.already_status", :status => env[:machine].state.id))
            return
          end

          env[:ui].info("Burning instance #{server.id} into an ami")
          ami_response = server.service.create_image server.id, "#{server.tags["Name"]} Package - #{Time.now.strftime("%Y%m%d-%H%M%S")}", "No description..."

          begin

            # Find ami object
            ami_id = ami_response.data[:body]["imageId"]
            ami_obj = server.service.images.get(ami_id)
            
            env[:metrics]["instance_ready_time"] = Util::Timer.time do
            
              env[:ui].info("Waiting for the AMI '#{ami_id}' to burn...")
              begin
                retryable(:on => Fog::Errors::TimeoutError, :tries => 300) do
                  # If we're interrupted don't worry about waiting
                  next if env[:interrupted]

                  # ACTUALLY need to update the ami_obj probably....
                  ami_obj = server.service.images.get(ami_id)
                  # Wait for the server to be ready 
                  server.wait_for(2) { 
                    if ami_obj.state == "failed"
                      raise Errors::InstancePackageError, 
                        ami_id: ami_id,
                        err: ami_obj.state
                    else
                      ami_obj.ready?
                    end
                  }
                end
              rescue Fog::Errors::TimeoutError
                # Notify the user
                raise Errors::InstanceReadyTimeout,
                  timeout: region_config.instance_ready_timeout
              end
            end
            env[:ui].info("Burn was successfull in #{env[:metrics]["instance_ready_time"].to_i}s")
            rescue Fog::Compute::AWS::Error => e
              raise Errors::FogError, :message => e.message
          end
          @app.call(env)
        end
      end
    end
  end
end
