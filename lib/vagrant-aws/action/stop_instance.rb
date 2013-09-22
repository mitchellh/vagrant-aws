require "log4r"

module VagrantPlugins
  module AWS
    module Action
      # This stops the running instance.
      class StopInstance
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_aws::action::stop_instance")
        end

        def call(env)
          server = env[:aws_compute].servers.get(env[:machine].id)

          if env[:machine].state.id == :stopped
            env[:ui].info(I18n.t("vagrant_aws.already_status", :status => env[:machine].state.id))
          else
            env[:ui].info(I18n.t("vagrant_aws.stopping"))
            server.stop(!!env[:force_halt])
          end

          @app.call(env)
        end
      end
    end
  end
end
