require "fog"
require "log4r"

module VagrantPlugins
  module AWS
    module Action
      # This action connects to AWS, verifies credentials work, and
      # puts the AWS connection object into the `:aws_compute` key
      # in the environment.
      class GetWinRMPassword
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_aws::action::get_winrm_password")
        end

        def call(env)
          machine = env[:machine]

          if machine.config.winrm.password == :aws && machine.config.ssh.private_key_path
            machine.ui.info(I18n.t("vagrant_aws.getting_winrm_password"))

            aws           = env[:aws_compute]
            response      = aws.get_password_data(machine.id)
            password_data = response.body['passwordData']

            if password_data
              password_data_bytes = Base64.decode64(password_data)

              # Try to decrypt the password data using each one of the private key files
              # set by the user until we hit one that decrypts successfully
              machine.config.ssh.private_key_path.each do |private_key_path|
                private_key_path = File.expand_path private_key_path

                @logger.info("Decrypting password data using #{private_key_path}")
                rsa = OpenSSL::PKey::RSA.new File.read private_key_path
                begin
                  machine.config.winrm.password = rsa.private_decrypt password_data_bytes
                  @logger.info("Successfully decrypted password data using #{private_key_path}")
                rescue OpenSSL::PKey::RSAError
                  @logger.warn("Failed to decrypt password data using #{private_key_path}")
                  next
                end

                break
              end              
            end
          end

          @app.call(env)
        end
      end
    end
  end
end
