require "log4r"

module VagrantPlugins
  module AWS
    module Action
      # This starts a stopped instance.
      class StartInstance
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_aws::action::start_instance")
        end

        def call(env)
          server = env[:aws_compute].servers.get(env[:machine].id)

          env[:ui].info(I18n.t("vagrant_aws.starting"))
          server.start

          @app.call(env)
        end
      end
    end
  end
end
