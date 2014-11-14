require "log4r"

require "vagrant/util/subprocess"

require "vagrant/util/scoped_hash_override"

require "vagrant/util/which"

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

          if env[:machine].guest.capability?(:rsync_installed)
            installed = env[:machine].guest.capability(:rsync_installed)
            if !installed
              can_install = env[:machine].guest.capability?(:rsync_install)
              if !can_install
                env[:ui].warn(I18n.t('vagrant_aws.rsync_not_found_warning', :side => "host"))
                return
              end
              env[:machine].ui.info I18n.t("vagrant.rsync_installing")
              env[:machine].guest.capability(:rsync_install)
            end
          end

          if env[:machine].communicate.execute('which rsync', :error_check => false) != 0
            env[:ui].warn(I18n.t('vagrant_aws.rsync_not_found_warning', :side => "guest"))
            return
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

            # on windows rsync.exe requires cygdrive-style paths
            if Vagrant::Util::Platform.windows?
              hostpath = hostpath.gsub(/^(\w):/) { "/cygdrive/#{$1}" }
            end

            env[:ui].info(I18n.t("vagrant_aws.rsync_folder",
                                :hostpath => hostpath,
                                :guestpath => guestpath))

            # Create the host path if it doesn't exist and option flag is set
            if data[:create]
              begin
                FileUtils::mkdir_p(hostpath)
              rescue => err
                raise Errors::MkdirError,
                  :hostpath => hostpath,
                  :err => err
              end
            end

            # Create the guest path
            env[:machine].communicate.sudo("mkdir -p '#{guestpath}'")
            env[:machine].communicate.sudo(
              "chown -R #{ssh_info[:username]} '#{guestpath}'")

            #collect rsync excludes specified :rsync_excludes=>['path1',...] in synced_folder options
            excludes = ['.vagrant/', 'Vagrantfile', *Array(data[:rsync_excludes])].uniq

            ssh_options = ["StrictHostKeyChecking=no"]
	    # Use proxy command if it's set
            if ssh_info[:proxy_command]
              ssh_options.push("ProxyCommand #{ssh_info[:proxy_command]}")
            end

            # Rsync over to the guest path using the SSH info
            command = [
              "rsync", "--verbose", "--archive", "-z", "--delete",
              *excludes.map{|e|['--exclude', e]}.flatten,
              "-e", "ssh -p #{ssh_info[:port]} #{ssh_key_options(ssh_info)} " + 
              ssh_options_to_args(ssh_options).join(' '),
              hostpath,
              "#{ssh_info[:username]}@#{ssh_info[:host]}:#{guestpath}"]

            # we need to fix permissions when using rsync.exe on windows, see
            # http://stackoverflow.com/questions/5798807/rsync-permission-denied-created-directories-have-no-permissions
            if Vagrant::Util::Platform.windows?
              command.insert(1, "--chmod", "ugo=rwX")
            end

            r = Vagrant::Util::Subprocess.execute(*command)
            if r.exit_code != 0
              raise Errors::RsyncError,
                :guestpath => guestpath,
                :hostpath => hostpath,
                :stderr => r.stderr
            end
          end
        end

        # Generate a ssh(1) command line list of options
        #
        # @param [Array] options An array of ssh options. E.g.
        #   `StrictHostKeyChecking=no` see ssh_config(5) for more
        # @return [Array] Computed list of command line arguments
        def ssh_options_to_args(options)
          # Bail early if we get something that is not an array of options
          return [] unless options

          return options.map { |o| "-o '#{o}'" }
        end

        private

        def ssh_key_options(ssh_info)
          # Ensure that `private_key_path` is an Array (for Vagrant < 1.4)
          Array(ssh_info[:private_key_path]).map { |path| "-i '#{path}' " }.join
        end
      end
    end
  end
end
