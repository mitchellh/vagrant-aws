require "vagrant"
require "iniparse"

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

      # The availability zone to launch the instance into. If nil, it will
      # use the default for your account.
      #
      # @return [String]
      attr_accessor :availability_zone

      # The placement group to launch the instance into. If nil, it will
      # not use a placement group
      #
      # @return [String]
      attr_accessor :placement_group

      # The timeout to wait for an instance to become ready.
      #
      # @return [Fixnum]
      attr_accessor :instance_ready_timeout

      # The interval to wait for checking an instance's state.
      #
      # @return [Fixnum]
      attr_accessor :instance_check_interval

      # The timeout to wait for an instance to successfully burn into an AMI.
      #
      # @return [Fixnum]
      attr_accessor :instance_package_timeout

      # The type of instance to launch, such as "m3.medium"
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

      # If true, acquire and attach an elastic IP address.
      # If set to an IP address, assign to the instance.
      #
      # @return [String]
      attr_accessor :elastic_ip

      # The name of the AWS region in which to create the instance.
      #
      # @return [String]
      attr_accessor :region

      # The EC2 endpoint to connect to
      #
      # @return [String]
      attr_accessor :endpoint

      # The version of the AWS api to use
      #
      # @return [String]
      attr_accessor :version

      # The secret access key for accessing AWS.
      #
      # @return [String]
      attr_accessor :secret_access_key

      # The token associated with the key for accessing AWS.
      #
      # @return [String]
      attr_accessor :session_token

      # The security groups to set on the instance. For VPC this must
      # be a list of IDs. For EC2, it can be either.
      #
      # @return [Array<String>]
      attr_reader :security_groups

      # The Amazon resource name (ARN) of the IAM Instance Profile
      # to associate with the instance.
      #
      # @return [String]
      attr_accessor :iam_instance_profile_arn

      # The name of the IAM Instance Profile to associate with
      # the instance.
      #
      # @return [String]
      attr_accessor :iam_instance_profile_name

      # The subnet ID to launch the machine into (VPC).
      #
      # @return [String]
      attr_accessor :subnet_id

      # The tags for the machine.
      #
      # @return [Hash<String, String>]
      attr_accessor :tags

      # The tags for the AMI generated with package.
      #
      # @return [Hash<String, String>]
      attr_accessor :package_tags

      # Use IAM Instance Role for authentication to AWS instead of an
      # explicit access_id and secret_access_key
      #
      # @return [Boolean]
      attr_accessor :use_iam_profile

      # The user data string
      #
      # @return [String]
      attr_accessor :user_data

      # Block device mappings
      #
      # @return [Array<Hash>]
      attr_accessor :block_device_mapping

      # Indicates whether an instance stops or terminates when you initiate shutdown from the instance
      #
      # @return [bool]
      attr_accessor :terminate_on_shutdown

      # Specifies which address to connect to with ssh
      # Must be one of:
      #  - :public_ip_address
      #  - :dns_name
      #  - :private_ip_address
      # This attribute also accepts an array of symbols
      #
      # @return [Symbol]
      attr_accessor :ssh_host_attribute

      # Enables Monitoring
      #
      # @return [Boolean]
      attr_accessor :monitoring

      # EBS optimized instance
      #
      # @return [Boolean]
      attr_accessor :ebs_optimized

      # Source Destination check
      #
      # @return [Boolean]
      attr_accessor :source_dest_check

      # Assigning a public IP address in a VPC
      #
      # @return [Boolean]
      attr_accessor :associate_public_ip

      # The name of ELB, which an instance should be
      # attached to
      #
      # @return [String]
      attr_accessor :elb

      # Disable unregisering ELB's from AZ - useful in case of not using default VPC
      # @return [Boolean]
      attr_accessor :unregister_elb_from_az

      # Kernel Id
      #
      # @return [String]
      attr_accessor :kernel_id

      # The tenancy of the instance in a VPC.
      # Defaults to 'default'.
      #
      # @return [String]
      attr_accessor :tenancy

      # The directory where AWS files are stored (usually $HOME/.aws)
      #
      # @return [String]
      attr_accessor :aws_dir

      # The selected AWS named profile (as defined in $HOME/.aws/* files)
      #
      # @return [String]
      attr_accessor :aws_profile

      def initialize(region_specific=false)
        @access_key_id             = UNSET_VALUE
        @ami                       = UNSET_VALUE
        @availability_zone         = UNSET_VALUE
        @instance_check_interval   = UNSET_VALUE
        @placement_group           = UNSET_VALUE
        @instance_ready_timeout    = UNSET_VALUE
        @instance_package_timeout  = UNSET_VALUE
        @instance_type             = UNSET_VALUE
        @keypair_name              = UNSET_VALUE
        @private_ip_address        = UNSET_VALUE
        @region                    = UNSET_VALUE
        @endpoint                  = UNSET_VALUE
        @version                   = UNSET_VALUE
        @secret_access_key         = UNSET_VALUE
        @session_token             = UNSET_VALUE
        @security_groups           = UNSET_VALUE
        @subnet_id                 = UNSET_VALUE
        @tags                      = {}
        @package_tags              = {}
        @user_data                 = UNSET_VALUE
        @use_iam_profile           = UNSET_VALUE
        @block_device_mapping      = []
        @elastic_ip                = UNSET_VALUE
        @iam_instance_profile_arn  = UNSET_VALUE
        @iam_instance_profile_name = UNSET_VALUE
        @terminate_on_shutdown     = UNSET_VALUE
        @ssh_host_attribute        = UNSET_VALUE
        @monitoring                = UNSET_VALUE
        @ebs_optimized             = UNSET_VALUE
        @source_dest_check         = UNSET_VALUE
        @associate_public_ip       = UNSET_VALUE
        @elb                       = UNSET_VALUE
        @unregister_elb_from_az    = UNSET_VALUE
        @kernel_id                 = UNSET_VALUE
        @tenancy                   = UNSET_VALUE
        @aws_dir                   = UNSET_VALUE
        @aws_profile               = UNSET_VALUE

        # Internal state (prefix with __ so they aren't automatically
        # merged)
        @__compiled_region_configs = {}
        @__finalized = false
        @__region_config = {}
        @__region_specific = region_specific
      end

      # set security_groups
      def security_groups=(value)
        # convert value to array if necessary
        @security_groups = value.is_a?(Array) ? value : [value]
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

          # Merge in the tags
          result.tags.merge!(self.tags)
          result.tags.merge!(other.tags)

          # Merge in the package tags
          result.package_tags.merge!(self.package_tags)
          result.package_tags.merge!(other.package_tags)

          # Merge block_device_mapping
          result.block_device_mapping |= self.block_device_mapping
          result.block_device_mapping |= other.block_device_mapping
        end
      end

      def finalize!
        # If access_key_id or secret_access_key were not specified in Vagrantfile
        # then try to read from environment variables first, and if it fails from
        # the AWS folder.
        if @access_key_id == UNSET_VALUE or @secret_access_key == UNSET_VALUE
          @aws_profile = 'default' if @aws_profile == UNSET_VALUE
          @aws_dir = ENV['HOME'].to_s + '/.aws/' if @aws_dir == UNSET_VALUE
          @aws_region, @access_key_id, @secret_access_key, @session_token = Credentials.new.get_aws_info(@aws_profile, @aws_dir)
          @region = @aws_region if @region == UNSET_VALUE and !@aws_region.nil?
        else
          @aws_profile = nil
          @aws_dir = nil
        end

        # session token must be set to nil, empty string isn't enough!
        @session_token = nil if @session_token == UNSET_VALUE

        # AMI must be nil, since we can't default that
        @ami = nil if @ami == UNSET_VALUE

        # Set the default timeout for waiting for an instance to be ready
        @instance_ready_timeout = 120 if @instance_ready_timeout == UNSET_VALUE

        # Set the default interval to check instance state
        @instance_check_interval = 2 if @instance_check_interval == UNSET_VALUE

        # Set the default timeout for waiting for an instance to burn into and ami
        @instance_package_timeout = 600 if @instance_package_timeout == UNSET_VALUE

        # Default instance type is an m3.medium
        @instance_type = "m3.medium" if @instance_type == UNSET_VALUE

        # Keypair defaults to nil
        @keypair_name = nil if @keypair_name == UNSET_VALUE

        # Default the private IP to nil since VPC is not default
        @private_ip_address = nil if @private_ip_address == UNSET_VALUE

        # Acquire an elastic IP if requested
        @elastic_ip = nil if @elastic_ip == UNSET_VALUE

        # Default region is us-east-1. This is sensible because AWS
        # generally defaults to this as well.
        @region = "us-east-1" if @region == UNSET_VALUE
        @availability_zone = nil if @availability_zone == UNSET_VALUE
        @placement_group = nil if @placement_group == UNSET_VALUE
        @endpoint = nil if @endpoint == UNSET_VALUE
        @version = nil if @version == UNSET_VALUE

        # The security groups are empty by default.
        @security_groups = [] if @security_groups == UNSET_VALUE

        # Subnet is nil by default otherwise we'd launch into VPC.
        @subnet_id = nil if @subnet_id == UNSET_VALUE

        # IAM Instance profile arn/name is nil by default.
        @iam_instance_profile_arn   = nil if @iam_instance_profile_arn  == UNSET_VALUE
        @iam_instance_profile_name  = nil if @iam_instance_profile_name == UNSET_VALUE

        # By default we don't use an IAM profile
        @use_iam_profile = false if @use_iam_profile == UNSET_VALUE

        # User Data is nil by default
        @user_data = nil if @user_data == UNSET_VALUE

        # default false
        @terminate_on_shutdown = false if @terminate_on_shutdown == UNSET_VALUE

        # default to nil
        @ssh_host_attribute = nil if @ssh_host_attribute == UNSET_VALUE

        # default false
        @monitoring = false if @monitoring == UNSET_VALUE

        # default false
        @ebs_optimized = false if @ebs_optimized == UNSET_VALUE

        # default to nil
        @source_dest_check = nil if @source_dest_check == UNSET_VALUE

        # default false
        @associate_public_ip = false if @associate_public_ip == UNSET_VALUE

        # default 'default'
        @tenancy = "default" if @tenancy == UNSET_VALUE

        # Don't attach instance to any ELB by default
        @elb = nil if @elb == UNSET_VALUE

        @unregister_elb_from_az = true if @unregister_elb_from_az == UNSET_VALUE

        # default to nil
        @kernel_id = nil if @kernel_id == UNSET_VALUE

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
        errors = _detected_errors

        errors << I18n.t("vagrant_aws.config.aws_info_required",
          :profile => @aws_profile, :location => @aws_dir) if \
          @aws_profile and (@access_key_id.nil? or @secret_access_key.nil? or @region.nil?)

        errors << I18n.t("vagrant_aws.config.region_required") if @region.nil?

        if @region
          # Get the configuration for the region we're using and validate only
          # that region.
          config = get_region_config(@region)

          if !config.use_iam_profile
            errors << I18n.t("vagrant_aws.config.access_key_id_required") if \
              config.access_key_id.nil?
            errors << I18n.t("vagrant_aws.config.secret_access_key_required") if \
              config.secret_access_key.nil?
          end

          if config.associate_public_ip && !config.subnet_id
            errors << I18n.t("vagrant_aws.config.subnet_id_required_with_public_ip")
          end

          errors << I18n.t("vagrant_aws.config.ami_required", :region => @region)  if config.ami.nil?
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


    class Credentials < Vagrant.plugin("2", :config)
      # This module reads AWS config and credentials. 
      # Behaviour aims to mimic what is described in AWS documentation:
      # http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
      # http://docs.aws.amazon.com/cli/latest/topic/config-vars.html
      # Which is the following (stopping at the first successful case):
      # 1) read config and credentials from environment variables
      # 2) read config and credentials from files at location defined by environment variables
      # 3) read config and credentials from files at default location 
      #
      # The mandatory fields for a successful "get credentials" are the id and the secret keys.
      # Region is not required since Config#finalize falls back to sensible defaults.
      # The behaviour is all-or-nothing (ie: no mixing between vars and files).
      #
      # It also allows choosing a profile (by default it's [default]) and an "info"
      # directory (by default $HOME/.aws), which can be specified in the Vagrantfile.
      # Supported information: region, aws_access_key_id, aws_secret_access_key, and aws_session_token.

      def get_aws_info(profile, location)
        # read credentials from environment variables
        aws_region, aws_id, aws_secret, aws_token = read_aws_environment()
        # if nothing there, then read from files
        # (the _if_ doesn't check aws_region since Config#finalize sets one by default)
        if aws_id.to_s == '' or aws_secret.to_s == ''
          # check if there are env variables for credential location, if so use then
          aws_config = ENV['AWS_CONFIG_FILE'].to_s
          aws_creds = ENV['AWS_SHARED_CREDENTIALS_FILE'].to_s
          if aws_config == '' or aws_creds == ''
            aws_config = location + 'config'
            aws_creds = location + 'credentials'
          end
          if File.exist?(aws_config) and File.exist?(aws_creds)
            aws_region, aws_id, aws_secret, aws_token = read_aws_files(profile, aws_config, aws_creds)
          end
        end
        aws_region = nil if aws_region == ''
        aws_id     = nil if aws_id == ''
        aws_secret = nil if aws_secret == ''
        aws_token  = nil if aws_token == ''

        return aws_region, aws_id, aws_secret, aws_token
      end


      private

      def read_aws_files(profile, aws_config, aws_creds)
        # determine section in config ini file
        if profile == 'default'
          ini_profile = profile
        else
          ini_profile = 'profile ' + profile
        end
        # get info from config ini file for selected profile
        data = File.read(aws_config)
        doc_cfg = IniParse.parse(data)
        aws_region = doc_cfg[ini_profile]['region']

        # determine section in credentials ini file
        ini_profile = profile
        # get info from credentials ini file for selected profile
        data = File.read(aws_creds)
        doc_cfg = IniParse.parse(data)
        aws_id = doc_cfg[ini_profile]['aws_access_key_id']
        aws_secret = doc_cfg[ini_profile]['aws_secret_access_key']
        aws_token = doc_cfg[ini_profile]['aws_session_token']

        return aws_region, aws_id, aws_secret, aws_token
      end

      def read_aws_environment()
        aws_region = ENV['AWS_DEFAULT_REGION']
        aws_id = ENV['AWS_ACCESS_KEY_ID']
        aws_secret = ENV['AWS_SECRET_ACCESS_KEY']
        aws_token = ENV['AWS_SESSION_TOKEN']

        return aws_region, aws_id, aws_secret, aws_token
      end

    end


  end
end
