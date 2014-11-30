require "fog"
require "log4r"

module VagrantPlugins
  module AWS
    module Action
      # This action connects to AWS, verifies credentials work, and
      # puts the AWS connection object into the `:aws_compute` key
      # in the environment.
      class ConnectAWS
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_aws::action::connect_aws")
        end

        def call(env)
          # Get the region we're going to booting up in
          region = env[:machine].provider_config.region

          # Get the configs
          region_config = env[:machine].provider_config.get_region_config(region)

          # Build the fog config
          fog_config = {
            :provider => :aws,
            :region   => region
          }
          if region_config.use_iam_profile
            fog_config[:use_iam_profile] = true
          else
            fog_config[:aws_access_key_id] = region_config.access_key_id
            fog_config[:aws_secret_access_key] = region_config.secret_access_key
            fog_config[:aws_session_token] = region_config.session_token
          end

          fog_config[:endpoint] = region_config.endpoint if region_config.endpoint
          fog_config[:version]  = region_config.version if region_config.version

          @logger.info("Connecting to AWS...")
          env[:aws_compute] = Fog::Compute.new(fog_config)
          env[:aws_elb]     = Fog::AWS::ELB.new(fog_config.except(:provider, :endpoint))

          @app.call(env)
        end
      end
    end
  end
end
