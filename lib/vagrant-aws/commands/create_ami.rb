require 'optparse'

module VagrantPlugins
  module AWS
    class Command < Vagrant.plugin("2", :command)
      def execute

        options = {}

        opts = OptionParser.new do |o|
          o.banner = "Usage: vagrant create_ami [box-name] [box-url]"
          o.separator ""

          #o.on("--provider provider", String,
          #     "Back the machine with a specific provider.") do |provider|
          #  options[:provider] = provider
          #end

        end

        # Parse the options
        argv = parse_options(opts)
        return if !argv

        with_target_vms(argv, :reverse => true) do |machine|
          puts "Creating AMI for #{machine.name}"

          @env.action_runner.run(VagrantPlugins::AWS::Action.action_create_ami, {
            :machine    => machine
          })
        end

        puts "Hello!"
        0
      end
    end
  end
end
