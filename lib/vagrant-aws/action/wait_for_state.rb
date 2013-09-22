require "log4r"
require "timeout"

module VagrantPlugins
  module AWS
    module Action
      # This action will wait for a machine to reach a specific state or quit by timeout
      class WaitForState
        # env[:result] will be false in case of timeout.
        # @param [Symbol] state Target machine state.
        # @param [Number] timeout Timeout in seconds.
        def initialize(app, env, state, timeout)
          @app     = app
          @logger  = Log4r::Logger.new("vagrant_aws::action::wait_for_state")
          @state   = state
          @timeout = timeout
        end

        def call(env)
          env[:result] = true
          if env[:machine].state.id == @state
            @logger.info(I18n.t("vagrant_aws.already_status", :status => @state))
          else
            @logger.info("Waiting for machine to reach state #{@state}")
            begin
              Timeout.timeout(@timeout) do
                until env[:machine].state.id == @state
                  sleep 2
                end
              end
            rescue Timeout::Error
              env[:result] = false # couldn't reach state in time
            end
          end

          @app.call(env)
        end
      end
    end
  end
end
