require "vagrant-aws/config"
require 'rspec/its'

describe VagrantPlugins::AWS::Config do
  let(:instance) { described_class.new }

  # Ensure tests are not affected by AWS credential environment variables
  before :each do
    ENV.stub(:[] => nil)
  end

  describe "defaults" do
    subject do
      instance.tap do |o|
        o.finalize!
      end
    end

    its("access_key_id")     { should be_nil }
    its("ami")               { should be_nil }
    its("availability_zone") { should be_nil }
    its("instance_ready_timeout") { should == 120 }
    its("instance_check_interval") { should == 2 }
    its("instance_package_timeout") { should == 600 }
    its("instance_type")     { should == "m3.medium" }
    its("keypair_name")      { should be_nil }
    its("private_ip_address") { should be_nil }
    its("region")            { should == "us-east-1" }
    its("secret_access_key") { should be_nil }
    its("session_token") { should be_nil }
    its("security_groups")   { should == [] }
    its("subnet_id")         { should be_nil }
    its("iam_instance_profile_arn") { should be_nil }
    its("iam_instance_profile_name") { should be_nil }
    its("tags")              { should == {} }
    its("package_tags")      { should == {} }
    its("user_data")         { should be_nil }
    its("use_iam_profile")   { should be false }
    its("block_device_mapping")  {should == [] }
    its("elastic_ip")        { should be_nil }
    its("terminate_on_shutdown") { should == false }
    its("ssh_host_attribute") { should be_nil }
    its("monitoring")        { should == false }
    its("ebs_optimized")     { should == false }
    its("source_dest_check")       { should be_nil }
    its("associate_public_ip")     { should == false }
    its("unregister_elb_from_az") { should == true }
    its("tenancy")     { should == "default" }
  end

  describe "overriding defaults" do
    # I typically don't meta-program in tests, but this is a very
    # simple boilerplate test, so I cut corners here. It just sets
    # each of these attributes to "foo" in isolation, and reads the value
    # and asserts the proper result comes back out.
    [:access_key_id, :ami, :availability_zone, :instance_ready_timeout,
      :instance_package_timeout, :instance_type, :keypair_name, :ssh_host_attribute,
      :ebs_optimized, :region, :secret_access_key, :session_token, :monitoring,
      :associate_public_ip, :subnet_id, :tags, :package_tags, :elastic_ip,
      :terminate_on_shutdown, :iam_instance_profile_arn, :iam_instance_profile_name,
      :use_iam_profile, :user_data, :block_device_mapping,
      :source_dest_check].each do |attribute|

      it "should not default #{attribute} if overridden" do
        instance.send("#{attribute}=".to_sym, "foo")
        instance.finalize!
        instance.send(attribute).should == "foo"
      end
    end
    it "should not default security_groups if overridden" do
      instance.security_groups = "foo"
      instance.finalize!
      instance.security_groups.should == ["foo"]
    end
  end

  describe "getting credentials from environment" do
    context "without EC2 credential environment variables" do
      subject do
        instance.tap do |o|
          o.finalize!
        end
      end

      its("access_key_id")     { should be_nil }
      its("secret_access_key") { should be_nil }
      its("session_token")     { should be_nil }
    end

    context "with EC2 credential environment variables" do
      before :each do
        ENV.stub(:[]).with("AWS_ACCESS_KEY").and_return("access_key")
        ENV.stub(:[]).with("AWS_SECRET_KEY").and_return("secret_key")
        ENV.stub(:[]).with("AWS_SESSION_TOKEN").and_return("session_token")
      end

      subject do
        instance.tap do |o|
          o.finalize!
        end
      end

      its("access_key_id")     { should == "access_key" }
      its("secret_access_key") { should == "secret_key" }
      its("session_token")     { should == "session_token" }
    end
  end

  describe "region config" do
    let(:config_access_key_id)     { "foo" }
    let(:config_ami)               { "foo" }
    let(:config_instance_type)     { "foo" }
    let(:config_keypair_name)      { "foo" }
    let(:config_region)            { "foo" }
    let(:config_secret_access_key) { "foo" }
    let(:config_session_token)     { "foo" }

    def set_test_values(instance)
      instance.access_key_id     = config_access_key_id
      instance.ami               = config_ami
      instance.instance_type     = config_instance_type
      instance.keypair_name      = config_keypair_name
      instance.region            = config_region
      instance.secret_access_key = config_secret_access_key
      instance.session_token     = config_session_token
    end

    it "should raise an exception if not finalized" do
      expect { instance.get_region_config("us-east-1") }.
        to raise_error
    end

    context "with no specific config set" do
      subject do
        # Set the values on the top-level object
        set_test_values(instance)

        # Finalize so we can get the region config
        instance.finalize!

        # Get a lower level region
        instance.get_region_config("us-east-1")
      end

      its("access_key_id")     { should == config_access_key_id }
      its("ami")               { should == config_ami }
      its("instance_type")     { should == config_instance_type }
      its("keypair_name")      { should == config_keypair_name }
      its("region")            { should == config_region }
      its("secret_access_key") { should == config_secret_access_key }
      its("session_token")     { should == config_session_token }
    end

    context "with a specific config set" do
      let(:region_name) { "hashi-region" }

      subject do
        # Set the values on a specific region
        instance.region_config region_name do |config|
          set_test_values(config)
        end

        # Finalize so we can get the region config
        instance.finalize!

        # Get the region
        instance.get_region_config(region_name)
      end

      its("access_key_id")     { should == config_access_key_id }
      its("ami")               { should == config_ami }
      its("instance_type")     { should == config_instance_type }
      its("keypair_name")      { should == config_keypair_name }
      its("region")            { should == region_name }
      its("secret_access_key") { should == config_secret_access_key }
      its("session_token")     { should == config_session_token }
    end

    describe "inheritance of parent config" do
      let(:region_name) { "hashi-region" }

      subject do
        # Set the values on a specific region
        instance.region_config region_name do |config|
          config.ami = "child"
        end

        # Set some top-level values
        instance.access_key_id = "parent"
        instance.ami = "parent"

        # Finalize and get the region
        instance.finalize!
        instance.get_region_config(region_name)
      end

      its("access_key_id") { should == "parent" }
      its("ami")           { should == "child" }
    end

    describe "shortcut configuration" do
      subject do
        # Use the shortcut configuration to set some values
        instance.region_config "us-east-1", :ami => "child"
        instance.finalize!
        instance.get_region_config("us-east-1")
      end

      its("ami") { should == "child" }
    end

    describe "merging" do
      let(:first)  { described_class.new }
      let(:second) { described_class.new }

      it "should merge the tags and block_device_mappings" do
        first.tags["one"] = "one"
        second.tags["two"] = "two"
        first.package_tags["three"] = "three"
        second.package_tags["four"] = "four"
        first.block_device_mapping = [{:one => "one"}]
        second.block_device_mapping = [{:two => "two"}]

        third = first.merge(second)
        third.tags.should == {
          "one" => "one",
          "two" => "two"
        }
        third.package_tags.should == {
          "three" => "three",
          "four" => "four"
        }
        third.block_device_mapping.index({:one => "one"}).should_not be_nil
        third.block_device_mapping.index({:two => "two"}).should_not be_nil
      end
    end
  end
end
