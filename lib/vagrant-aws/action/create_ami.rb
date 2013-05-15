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
          # Initialize metrics if they haven't been
          env[:metrics] ||= {}
          puts "Testing"

        end
      end
    end
  end
end
