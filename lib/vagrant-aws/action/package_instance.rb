require "log4r"
require 'vagrant/util/template_renderer'
require 'vagrant-aws/util/timer'
require 'vagrant/action/general/package'

module VagrantPlugins
  module AWS
    module Action
      # This packges the running instance.
      class PackageInstance < Vagrant::Action::General::Package
        include Vagrant::Util::Retryable

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_aws::action::stop_instance")
          env["package.include"] ||= []
          env["package.vagrantfile"] ||= nil
          env["package.output"] ||= "package.box"

        end

        alias_method :general_call, :call
        def call(env)
          # Initialize metrics if they haven't been
          env[:metrics] ||= {}

          if env[:machine].state.id == :stopped
            env[:ui].info(I18n.t("vagrant_aws.already_status", :status => env[:machine].state.id))
            return
          end

          # Burn instance to an ami
          begin
            server = env[:aws_compute].servers.get(env[:machine].id)  
            env[:ui].info("Burning instance #{server.id} into an ami")
            ami_response = server.service.create_image server.id, "#{server.tags["Name"]} Package - #{Time.now.strftime("%Y%m%d-%H%M%S")}", "No description..."

            # Find ami object
            @ami_id = ami_response.data[:body]["imageId"]
            ami_obj = server.service.images.get(@ami_id)
            
            env[:metrics]["instance_ready_time"] = Util::Timer.time do
            
              env[:ui].info("Waiting for the AMI '#{@ami_id}' to burn...")
              begin
                retryable(:on => Fog::Errors::TimeoutError, :tries => 300) do
                  # If we're interrupted don't worry about waiting
                  next if env[:interrupted]

                  # ACTUALLY need to update the ami_obj probably....
                  ami_obj = server.service.images.get(@ami_id)
                  # Wait for the server to be ready 
                  server.wait_for(2) { 
                    if ami_obj.state == "failed"
                      raise Errors::InstancePackageError, 
                        ami_id: ami_obj.id,
                        err: ami_obj.state
                      return
                    else
                      ami_obj.ready?
                    end
                  }
                end # Retryable end
              rescue Fog::Errors::TimeoutError
                # Notify the user
                raise Errors::InstanceReadyTimeout,
                  timeout: region_config.instance_ready_timeout
              end # Begin, end
            end # Timer.time end
            env[:ui].info("Burn was successfull in #{env[:metrics]["instance_ready_time"].to_i}s")
          rescue Fog::Compute::AWS::Error => e
            raise Errors::FogError, :message => e.message
          end # Begin, end

          # Create the .box 
          begin

            setup_package_files env

            # Setup the temporary directory
            @temp_dir = env[:tmp_path].join(Time.now.to_i.to_s)
            env["export.temp_dir"] = @temp_dir
            FileUtils.mkpath(env["export.temp_dir"])

            # Just match up a couple environmental variables so that
            # the superclass will do the right thing. Then, call the
            # superclass
            env["package.directory"] = env["export.temp_dir"]

            create_vagrantfile(env)
            create_metadata_file(env)

            general_call(env)
            
            # Always call recover to clean up the temp dir
            clean_temp_dir

          rescue Errors::VagrantAWSError => e
            p "There was an error: #{e}"
          end

        end # End call

        def recover(env)
          clean_temp_dir
        end

        protected

        def clean_temp_dir
          if @temp_dir && File.exist?(@temp_dir)
            FileUtils.rm_rf(@temp_dir)
          end
        end

        # This method creates the auto-generated Vagrantfile at the root of the
        # box.
        def create_vagrantfile env
          File.open(File.join(env["export.temp_dir"], "Vagrantfile"), "w") do |f|
            f.write(TemplateRenderer.render("vagrant-aws_package_Vagrantfile", {
              region: env[:machine].provider_config.region,
              ami: @ami_id,
              template_root: template_root
            }))
          end
        end

        def create_metadata_file env
          File.open(File.join(env["export.temp_dir"], "metadata.json"), "w") do |f|
            f.write(TemplateRenderer.render("metadata.json", {
              template_root: template_root
            }))
          end
        end

        def setup_package_files(env)
          files = {}
          env["package.include"].each do |file|
            source = Pathname.new(file)
            dest   = nil

            # If the source is relative then we add the file as-is to the include
            # directory. Otherwise, we copy only the file into the root of the
            # include directory. Kind of strange, but seems to match what people
            # expect based on history.
            if source.relative?
              dest = source
            else
              dest = source.basename
            end

            # Assign the mapping
            files[file] = dest
          end

          if env["package.vagrantfile"]
            # Vagrantfiles are treated special and mapped to a specific file
            files[env["package.vagrantfile"]] = "_Vagrantfile"
          end

          # Verify the mapping
          files.each do |from, _|
            raise Vagrant::Errors::PackageIncludeMissing,
              file: from if !File.exist?(from)
          end

          # Save the mapping
          env["package.files"] = files

          @app.call(env)
        end

        def template_root
          Pathname.new(File.expand_path('../../../../', __FILE__)).join("templates")
        end

      end
    end
  end
end
