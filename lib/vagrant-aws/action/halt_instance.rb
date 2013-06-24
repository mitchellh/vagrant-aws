require "log4r"

module VagrantPlugins
  module AWS
    module Action
      # This halts the running instance.
      class HaltInstance
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_aws::action::halt_instance")
        end

        def call(env)
          server = env[:aws_compute].servers.get(env[:machine].id)

          # Destroy the server and remove the tracking ID
          env[:ui].info(I18n.t("vagrant_aws.halting"))
          server.stop

          @app.call(env)
        end
      end
    end
  end
end
