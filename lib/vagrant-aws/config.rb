require "vagrant"

module VagrantPlugins
  module AWS
    class Config < Vagrant.plugin("2", :config)
      # The access key ID for accessing AWS.
      #
      # @return [String]
      attr_accessor :access_key_id

      # The ID of the AMI to use.
      #
      # @return [String]
      attr_accessor :ami

      # The type of instance to launch, such as "m1.small"
      #
      # @return [String]
      attr_accessor :instance_type

      # The name of the keypair to use.
      #
      # @return [String]
      attr_accessor :keypair_name

      # The private IP address to give this machine (VPC).
      #
      # @return [String]
      attr_accessor :private_ip_address

      # The name of the AWS region in which to create the instance.
      #
      # @return [String]
      attr_accessor :region

      # The secret access key for accessing AWS.
      #
      # @return [String]
      attr_accessor :secret_access_key

      # The subnet ID to launch the machine into (VPC).
      #
      # @return [String]
      attr_accessor :subnet_id

      def initialize(region_specific=false)
        @access_key_id      = UNSET_VALUE
        @ami                = UNSET_VALUE
        @instance_type      = UNSET_VALUE
        @keypair_name       = UNSET_VALUE
        @private_ip_address = UNSET_VALUE
        @region             = UNSET_VALUE
        @secret_access_key  = UNSET_VALUE
        @subnet_id          = UNSET_VALUE

        # Internal state (prefix with __ so they aren't automatically
        # merged)
        @__compiled_region_configs = {}
        @__finalized = false
        @__region_config = {}
        @__region_specific = region_specific
      end

      # Allows region-specific overrides of any of the settings on this
      # configuration object. This allows the user to override things like
      # AMI and keypair name for regions. Example:
      #
      #     aws.region_config "us-east-1" do |region|
      #       region.ami = "ami-12345678"
      #       region.keypair_name = "company-east"
      #     end
      #
      # @param [String] region The region name to configure.
      # @param [Hash] attributes Direct attributes to set on the configuration
      #   as a shortcut instead of specifying a full block.
      # @yield [config] Yields a new AWS configuration.
      def region_config(region, attributes=nil, &block)
        # Append the block to the list of region configs for that region.
        # We'll evaluate these upon finalization.
        @__region_config[region] ||= []

        # Append a block that sets attributes if we got one
        if attributes
          attr_block = lambda do |config|
            config.set_options(attributes)
          end

          @__region_config[region] << attr_block
        end

        # Append a block if we got one
        @__region_config[region] << block if block_given?
      end

      #-------------------------------------------------------------------
      # Internal methods.
      #-------------------------------------------------------------------

      def merge(other)
        super.tap do |result|
          # Copy over the region specific flag. "True" is retained if either
          # has it.
          new_region_specific = other.instance_variable_get(:@__region_specific)
          result.instance_variable_set(
            :@__region_specific, new_region_specific || @__region_specific)

          # Go through all the region configs and prepend ours onto
          # theirs.
          new_region_config = other.instance_variable_get(:@__region_config)
          @__region_config.each do |key, value|
            new_region_config[key] ||= []
            new_region_config[key] = value + new_region_config[key]
          end

          # Set it
          result.instance_variable_set(:@__region_config, new_region_config)
        end
      end

      def finalize!
        # The access keys default to nil
        @access_key_id     = nil if @access_key_id     == UNSET_VALUE
        @secret_access_key = nil if @secret_access_key == UNSET_VALUE

        # AMI must be nil, since we can't default that
        @ami = nil if @ami == UNSET_VALUE

        # Default instance type is an m1.small
        @instance_type = "m1.small" if @instance_type == UNSET_VALUE

        # Keypair defaults to nil
        @keypair_name = nil if @keypair_name == UNSET_VALUE

        # Default the private IP to nil since VPC is not default
        @private_ip_address = nil if @private_ip_address == UNSET_VALUE

        # Default region is us-east-1. This is sensible because AWS
        # generally defaults to this as well.
        @region = "us-east-1" if @region == UNSET_VALUE

        # Subnet is nil by default otherwise we'd launch into VPC.
        @subnet_id = nil if @subnet_id == UNSET_VALUE

        # Compile our region specific configurations only within
        # NON-REGION-SPECIFIC configurations.
        if !@__region_specific
          @__region_config.each do |region, blocks|
            config = self.class.new(true).merge(self)

            # Execute the configuration for each block
            blocks.each { |b| b.call(config) }

            # The region name of the configuration always equals the
            # region config name:
            config.region = region

            # Finalize the configuration
            config.finalize!

            # Store it for retrieval
            @__compiled_region_configs[region] = config
          end
        end

        # Mark that we finalized
        @__finalized = true
      end

      def validate(machine)
        errors = []

        errors << I18n.t("vagrant_aws.config.region_required") if @region.nil?

        if @region
          # Get the configuration for the region we're using and validate only
          # that region.
          config = get_region_config(@region)

          errors << I18n.t("vagrant_aws.config.access_key_id_required") if \
            config.access_key_id.nil?
          errors << I18n.t("vagrant_aws.config.secret_access_key_required") if \
            config.secret_access_key.nil?
          errors << I18n.t("vagrant_aws.config.ami_required") if config.ami.nil?
        end

        { "AWS Provider" => errors }
      end

      # This gets the configuration for a specific region. It shouldn't
      # be called by the general public and is only used internally.
      def get_region_config(name)
        if !@__finalized
          raise "Configuration must be finalized before calling this method."
        end

        # Return the compiled region config
        @__compiled_region_configs[name] || self
      end
    end
  end
end
