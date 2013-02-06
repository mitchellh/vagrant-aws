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
          access_key_id = env[:machine].provider_config.access_key_id
          secret_access_key = env[:machine].provider_config.secret_access_key

          @logger.info("Connecting to AWS...")
          env[:aws_compute] = Fog::Compute.new({
            :provider => :aws,
            :aws_access_key_id => access_key_id,
            :aws_secret_access_key => secret_access_key
          })

          @app.call(env)
        end
      end
    end
  end
end
