module VagrantPlugins
  module AWS
    module ElasticLoadBalancer

      def register_instance(env, elb_name, instance_id)
        env[:ui].info I18n.t("vagrant_aws.elb.registering", instance_id: instance_id, elb_name: elb_name), :new_line => false
        elb = get_load_balancer(env[:aws_elb], elb_name)
        unless elb.instances.include? instance_id
          elb.register_instances([instance_id])
          env[:ui].info I18n.t("vagrant_aws.elb.ok"), :prefix => false
          adjust_availability_zones env, elb
        else
          env[:ui].info I18n.t("vagrant_aws.elb.skipped"), :prefix => false
        end
      end

      def deregister_instance(env, elb_name, instance_id)
        env[:ui].info I18n.t("vagrant_aws.elb.deregistering", instance_id: instance_id, elb_name: elb_name), :new_line => false
        elb = get_load_balancer(env[:aws_elb], elb_name)
        if elb.instances.include? instance_id
          elb.deregister_instances([instance_id])
          env[:ui].info I18n.t("vagrant_aws.elb.ok"), :prefix => false
          if env[:machine].provider_config.unregister_elb_from_az
            adjust_availability_zones env, elb
          end
        else
          env[:ui].info I18n.t("vagrant_aws.elb.skipped"), :prefix => false
        end
      end

      def adjust_availability_zones(env, elb)
        env[:ui].info I18n.t("vagrant_aws.elb.adjusting", elb_name: elb.id), :new_line => false

        instances = env[:aws_compute].servers.all("instance-id" => elb.instances)
        
        azs = if instances.empty?
                ["#{env[:machine].provider_config.region}a"]
              else
                instances.map(&:availability_zone).uniq
              end

        az_to_disable = elb.availability_zones - azs
        az_to_enable = azs - elb.availability_zones

        elb.enable_availability_zones az_to_enable unless az_to_enable.empty?
        elb.disable_availability_zones az_to_disable unless az_to_disable.empty?

        env[:ui].info I18n.t("vagrant_aws.elb.ok"), :prefix => false
      end

      private

      def get_load_balancer(aws, name)
        aws.load_balancers.find { |lb| lb.id == name } or raise Errors::ElbDoesNotExistError
      end
    end
  end
end
