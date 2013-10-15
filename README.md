# Vagrant AWS Provider

<span class="badges">
[![Gem Version](https://badge.fury.io/rb/vagrant-aws.png)][gem]
[![Dependency Status](https://gemnasium.com/mitchellh/vagrant-aws.png)][gemnasium]
</span>

[gem]: https://rubygems.org/gems/vagrant-aws
[gemnasium]: https://gemnasium.com/mitchellh/vagrant-aws

This is a [Vagrant](http://www.vagrantup.com) 1.2+ plugin that adds an [AWS](http://aws.amazon.com)
provider to Vagrant, allowing Vagrant to control and provision machines in
EC2 and VPC.

**NOTE:** This plugin requires Vagrant 1.2+,

## Features

* Boot EC2 or VPC instances.
* SSH into the instances.
* Provision the instances with any built-in Vagrant provisioner.
* Minimal synced folder support via `rsync`.
* Define region-specifc configurations so Vagrant can manage machines
  in multiple regions.
* Support for several AWS features like EIP, tags, block device mappings.

## Quick Start

Install vagrant-aws
```sh
$ vagrant plugin install vagrant-aws
```

Add a dummy box
```sh
$ vagrant box add dummy https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box
```

Create your Vagrantfile
```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "dummy"

  config.vm.provider :aws do |aws, override|
    aws.access_key_id = "YOUR KEY"
    aws.secret_access_key = "YOUR SECRET KEY"
    aws.keypair_name = "KEYPAIR NAME"

    aws.ami = "ami-7747d01e"

    override.ssh.username = "ubuntu"
    override.ssh.private_key_path = "PATH TO YOUR PRIVATE KEY"
  end
end
```

Start the vm
```sh
$ vagrant up --provider=aws
```

Other commands like `ssh`, `reload`, `destroy` are also available.

## Documentation

* [Box Format](#box-format)
* [Configuration](#configuration)
* [Networks](#networks)
* [Synced Folders](#synced-folders)
* [Vagrantfile Examples](#vagrantfile-examples)
* [Development](#development)
* [FAQ](#faq)

### Box Format

Every provider in Vagrant must introduce a custom box format. This
provider introduces `aws` boxes. You can view an example box in
the [example_box/ directory](https://github.com/mitchellh/vagrant-aws/tree/master/example_box).
That directory also contains instructions on how to build a box.

The box format is basically just the required `metadata.json` file
along with a `Vagrantfile` that does default settings for the
provider-specific configuration for this provider.

### Configuration

This provider exposes quite a few provider-specific configuration options.

Required options:
* `access_key_id` - The AWS access key.
* `secret_access_key` - The AWS secret access key.
* `ami` - The AMI id to boot.
* `keypair_name` - The name of the AWS keypair to use to bootstrap instance.

```ruby
    aws.access_key_id = "YOUR KEY"
    aws.secret_access_key = "YOUR SECRET KEY"
    aws.ami = "ami-deadbeef"
    aws.keypair_name = "KEYPAIR NAME"
```

Optionals:
* `region` - default *us-east-1* - The region to start the instance in.
* `availability_zone` - default *nil* -  The availability zone within the region to launch
  the instance. If nil, it will use the default set by Amazon. Example: **eu-west-1b**.
* `instance_ready_timeout` - default *120* - The number of seconds to wait for the instance
  to become "ready" in AWS.
* `instance_type` - default *m1.small* - The type of instance, such as **m1.medium**.
* `user_data` - default *nil* - AWS user data string. 
* `monitoring` - default *false* - Enable AWS instance monitoring.
* `ebs_optimized` - default *false* - Enable optimized EBS volume, check the `instance_type`
for support.
* `terminate_on_shutdown` - default *false* - If true will terminate the instance on shutdown instead of stop.
* `ssh_host_attribute` - default *nil* - Specifies which AWS attribute should be used as SSH host, examples: **:private_ip_address**,
 **:public_ip_address** or **:dns_name**.
* `iam_instance_profile_arn` - default *nil* - The Amazon resource name (ARN) of the IAM Instance
 Profile to associate with the instance.
* `iam_instance_profile_name` - default *nil* - The name of the IAM Instance Profile to associate
 with the instance.
* `use_iam_profile` - default *false* - Enables the use of [IAM profiles](http://docs.aws.amazon.com/IAM/latest/UserGuide/instance-profiles.html)
  for credentials.
* `subnet_id` - default *nil* - The subnet to boot the instance into, for VPC.
* `security_groups` - default *[]* - An array of security groups for the instance. If this
  instance will be launched in VPC, this must be a list of security group IDs.
* `elastic_ip` - default *false* - Acquire and attach an elastic IP address ([VPC](http://aws.amazon.com/vpc/)).
* `private_ip_address` - The private IP address to assign to an instance
  within a [VPC](http://aws.amazon.com/vpc/)
* `block_device_mapping` - default *[]* - An array of block devices, see [EBS volumes](#ebs-volumes) example.
* `tags` - default *{}* - A hash of tags to set on the machine. This can be used to set the instance name:

```ruby
    aws.tags = { :Name => "foobar" }
```

### Networks

Networking features in the form of `config.vm.network` are not
supported with vagrant-aws, currently. If any of these are
specified, Vagrant will emit a warning, but will otherwise boot
the AWS machine.

### Synced Networks

There is minimal support for synced folders. Upon `vagrant up`,
`vagrant reload`, and `vagrant provision`, the AWS provider will use
`rsync` (if available) to uni-directionally sync the folder to
the remote machine over SSH.

This is good enough for all built-in Vagrant provisioners (shell,
chef, and puppet) to work!

### Vagrantfile Examples

#### VPC

#### EBS volumes

### Development

To work on the `vagrant-aws` plugin, clone this repository out, and use
[Bundler](http://gembundler.com) to get the dependencies:

```sh
$ bundle
```

Once you have the dependencies, verify the unit tests pass with `rake`:
```sh
$ bundle exec rake
```

If those pass, you're ready to start developing the plugin. You can test
the plugin without installing it into your Vagrant environment by just
creating a `Vagrantfile` in the top level of this directory (it is gitignored)
and add the following line to your `Vagrantfile` 
```ruby
Vagrant.require_plugin "vagrant-aws"
```
Use bundler to execute Vagrant:
```sh
$ bundle exec vagrant up --provider=aws
```

Log output is controlled via the environment variable `VAGRANT_LOG`:
```sh
$ VAGRANT_LOG=debug bundle exec vagrant up --provider=aws
```

### FAQ

1. Which IP is used by the `ssh` command?

