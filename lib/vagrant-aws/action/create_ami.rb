require 'date'

module VagrantPlugins
  module AWS
    module Action
      # This runs the configured instance.
      class CreateAMI
        include Vagrant::Util::Retryable

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_aws::action::create_ami")
        end

        def call(env)
          if env[:machine].state.id != :running
            puts "Skipping #{env[:machine].name}: not running"
          else
            puts "Testing"
            #_create_ami(env[:machine].id)
            _create_ami(env)
          end

        end

        protected

        def _create_ami(env)
            # Default image name/description, if not given on command line
            # TODO accept AMI name/desc as command line arg
            image_name = "test-image-#{DateTime.now.strftime("%Y%m%d-%H%M%S")}"
            image_description = "testing vagrant imaging"

            server = env[:aws_compute].servers.get(env[:machine].id)
            # TODO error handling on create_image/tags
            data = env[:aws_compute].create_image(server.identity, image_name, image_description)
            image_id = data.body["imageId"]
            env[:aws_compute].create_tags(image_id, { :test1 => "test1" })
            #puts server.identity
            puts "Created AMI #{image_id}"
        end
      end
    end
  end
end
