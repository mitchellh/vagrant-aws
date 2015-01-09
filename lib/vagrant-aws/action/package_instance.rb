require "log4r"
require 'vagrant/util/template_renderer'
require 'vagrant-aws/util/timer'
require 'vagrant/action/general/package'

module VagrantPlugins
  module AWS
    module Action
      # This action packages a running aws-based server into an
      # aws-based vagrant box. It does so by burning the associated
      # vagrant-aws server instance, into an AMI via fog. Upon
      # successful AMI burning, the action will create a .box tarball
      # writing a Vagrantfile with the fresh AMI id into it.

      # Vagrant itself comes with a general package action, which 
      # this plugin action does call. The general action provides
      # the actual packaging as well as other options such as
      # --include for including additional files and --vagrantfile
      # which is pretty much not useful here anyway.

      # The virtualbox package plugin action was loosely used
      # as a model for this class.

      class PackageInstance < Vagrant::Action::General::Package
        include Vagrant::Util::Retryable

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_aws::action::package_instance")
          env["package.include"] ||= []
          env["package.output"] ||= "package.box"
        end

        alias_method :general_call, :call
        def call(env)
          # Initialize metrics if they haven't been
          env[:metrics] ||= {}

          # This block attempts to burn the server instance into an AMI
          begin
            # Get the Fog server object for given machine
            server = env[:aws_compute].servers.get(env[:machine].id)

            env[:ui].info(I18n.t("vagrant_aws.packaging_instance", :instance_id => server.id))
            
            # Make the request to AWS to create an AMI from machine's instance
            ami_response = server.service.create_image server.id, "#{server.tags["Name"]} Package - #{Time.now.strftime("%Y%m%d-%H%M%S")}", ""

            # Find ami id
            @ami_id = ami_response.data[:body]["imageId"]

            # Attempt to burn the aws instance into an AMI within timeout
            env[:metrics]["instance_ready_time"] = Util::Timer.time do
              
              # Get the config, to set the ami burn timeout
              region = env[:machine].provider_config.region
              region_config = env[:machine].provider_config.get_region_config(region)
              tries = region_config.instance_package_timeout / 2

              env[:ui].info(I18n.t("vagrant_aws.burning_ami", :ami_id => @ami_id))
              if !region_config.package_tags.empty?
                server.service.create_tags(@ami_id, region_config.package_tags)
              end

              # Check the status of the AMI every 2 seconds until the ami burn timeout has been reached
              begin
                retryable(:on => Fog::Errors::TimeoutError, :tries => tries) do
                  # If we're interrupted don't worry about waiting
                  next if env[:interrupted]

                  # Need to update the ami_obj on each cycle
                  ami_obj = server.service.images.get(@ami_id)

                  # Wait for the server to be ready, raise error if timeout reached 
                  server.wait_for(2) {
                    if ami_obj.state == "failed"
                      raise Errors::InstancePackageError, 
                        ami_id: ami_obj.id,
                        err: ami_obj.state
                    end

                    ami_obj.ready?
                  }
                end
              rescue Fog::Errors::TimeoutError
                # Notify the user upon timeout
                raise Errors::InstancePackageTimeout,
                  timeout: region_config.instance_package_timeout
              end
            end
            env[:ui].info(I18n.t("vagrant_aws.packaging_instance_complete", :time_seconds => env[:metrics]["instance_ready_time"].to_i))
          rescue Fog::Compute::AWS::Error => e
            raise Errors::FogError, :message => e.message
          end

          # Handles inclusions from --include and --vagrantfile options
          setup_package_files(env)

          # Setup the temporary directory for the tarball files
          @temp_dir = env[:tmp_path].join(Time.now.to_i.to_s)
          env["export.temp_dir"] = @temp_dir
          FileUtils.mkpath(env["export.temp_dir"])

          # Create the Vagrantfile and metadata.json files from templates to go in the box
          create_vagrantfile(env)
          create_metadata_file(env)

          # Just match up a couple environmental variables so that
          # the superclass will do the right thing. Then, call the
          # superclass to actually create the tarball (.box file)
          env["package.directory"] = env["export.temp_dir"]
          general_call(env)
          
          # Always call recover to clean up the temp dir
          clean_temp_dir
        end

        protected

        # Cleanup temp dir and files
        def clean_temp_dir
          if @temp_dir && File.exist?(@temp_dir)
            FileUtils.rm_rf(@temp_dir)
          end
        end

        # This method generates the Vagrantfile at the root of the box. Taken from 
        # VagrantPlugins::ProviderVirtualBox::Action::PackageVagrantfile
        def create_vagrantfile env
          File.open(File.join(env["export.temp_dir"], "Vagrantfile"), "w") do |f|
            f.write(TemplateRenderer.render("vagrant-aws_package_Vagrantfile", {
              region: env[:machine].provider_config.region,
              ami: @ami_id,
              template_root: template_root
            }))
          end
        end

        # This method generates the metadata.json file at the root of the box.
        def create_metadata_file env
          File.open(File.join(env["export.temp_dir"], "metadata.json"), "w") do |f|
            f.write(TemplateRenderer.render("metadata.json", {
              template_root: template_root
            }))
          end
        end

        # Sets up --include and --vagrantfile files which may be added as optional
        # parameters. Taken from VagrantPlugins::ProviderVirtualBox::Action::SetupPackageFiles
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
        end

        # Used to find the base location of aws-vagrant templates
        def template_root
          AWS.source_root.join("templates")
        end

      end
    end
  end
end
