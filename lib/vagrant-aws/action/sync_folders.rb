require "log4r"

require "vagrant/util/subprocess"

require "vagrant/util/scoped_hash_override"

module VagrantPlugins
  module AWS
    module Action
      # This middleware uses `rsync` to sync the folders over to the
      # AWS instance.
      class SyncFolders
        include Vagrant::Util::ScopedHashOverride

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_aws::action::sync_folders")
        end

        def call(env)
          @app.call(env)

          ssh_info = env[:machine].ssh_info

          region = env[:machine].provider_config.region
          region_config = env[:machine].provider_config.get_region_config(region)
          if region_config.install_chef_client
            # Wait chef-solo...
            env[:ui].info(I18n.t("vagrant_aws.waiting_to_install_chef_client"))
            env[:machine].communicate.execute("until sudo ls >/dev/null 2>&1; do sleep 1; done")
          end

          env[:machine].config.vm.synced_folders.each do |id, data|
            data = scoped_hash_override(data, :aws)

            # Ignore disabled shared folders
            next if data[:disabled]

            hostpath  = File.expand_path(data[:hostpath], env[:root_path])
            guestpath = data[:guestpath]

            # Make sure there is a trailing slash on the host path to
            # avoid creating an additional directory with rsync
            hostpath = "#{hostpath}/" if hostpath !~ /\/$/

            env[:ui].info(I18n.t("vagrant_aws.rsync_folder",
                                :hostpath => hostpath,
                                :guestpath => guestpath))

            # Create the guest path
            env[:machine].communicate.sudo("mkdir -p '#{guestpath}'")
            env[:machine].communicate.sudo(
              "chown #{ssh_info[:username]} '#{guestpath}'")

            # Rsync over to the guest path using the SSH info
            command = [
              "rsync", "--verbose", "--archive", "-z",
              "--exclude", ".vagrant/",
              "-e", "ssh -p #{ssh_info[:port]} -o StrictHostKeyChecking=no -i '#{ssh_info[:private_key_path]}'",
              hostpath,
              "#{ssh_info[:username]}@#{ssh_info[:host]}:#{guestpath}"]

            r = Vagrant::Util::Subprocess.execute(*command)
            if r.exit_code != 0
              raise Errors::RsyncError,
                :guestpath => guestpath,
                :hostpath => hostpath,
                :stderr => r.stderr
            end
          end
        end
      end
    end
  end
end
