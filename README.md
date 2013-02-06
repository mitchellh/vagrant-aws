# Vagrant AWS Provider

This is a [Vagrant](http://www.vagrantup.com) 1.1+ plugin that adds an [AWS](http://aws.amazon.com)
provider to Vagrant, allowing Vagrant to control and provision machines in
EC2 and VPC.

**NOTE:** This plugin requires Vagrant 1.1+, which is still unreleased.
Vagrant 1.1 will be released soon. In the mean time, this repository is
meant as an example of a high quality plugin using the new plugin system
in Vagrant.

## Features

* Boot EC2 or VPC instances.
* SSH into the instances.
* Provision the instances with any built-in Vagrant provisioner.
* Minimal synced folder support via `rsync`.
* Define region-specifc configurations so Vagrant can manage machines
  in multiple regions.

## Usage

Install using standard Vagrant 1.1+ plugin installation methods. After
installing, `vagrant up` and specify the `aws` provider. An example is
shown below.

```
$ vagrant plugin install vagrant-aws
...
$ vagrant up --provider=aws
...
```

Of course prior to doing this, you'll need to obtain an AWS-compatible
box file for Vagrant.

## Box Format

Every provider in Vagrant must introduce a custom box format. This
provider introduces `aws` boxes. You can view an example box in
the [example_box/ directory](https://github.com/mitchellh/vagrant-aws/tree/master/example_box).
That directory also contains instructions on how to build a box.

The box format is basically just the required `metadata.json` file
along with a `Vagrantfile` that does default settings for the
provider-specific configuration for this provider.

## Configuration

This provider exposes quite a few provider-specific configuration options:

* `access_key_id` - The access key for accessing AWS
* `ami` - The AMI id to boot, such as "ami-12345678"
* `instance_type` - The type of instance, such as "m1.small"
* `keypair_name` - The name of the keypair to use to bootstrap AMIs
   which support it.
* `private_ip_address` - The private IP address to assign to an instance
  within a [VPC](http://aws.amazon.com/vpc/)
* `region` - The region to start the instance in, such as "us-east-1"
* `secret_access_key` - The secret access key for accessing AWS
* `ssh_private_key_path` - The path to the SSH private key. This overrides
  `config.ssh.private_key_path`.
* `ssh_username` - The SSH username, which overrides `config.ssh.username`.
* `subnet_id` - The subnet to boot the instance into, for VPC.

These can be set like typical provider-specific configuration:

```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :aws do |aws|
    aws.access_key_id = "foo"
    aws.secret_access_key = "bar"
  end
end
```

In addition to the above top-level configs, you can use the `region_config`
method to specify region-specific overrides within your Vagrantfile. Note
that the top-level `region` config must always be specified to choose which
region you want to actually use, however. This looks like this:

```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :aws do |aws|
    aws.access_key_id = "foo"
    aws.secret_access_key = "bar"
    aws.region = "us-east-1"

    # Simply region config
    aws.region_config "us-east-1", :ami => "ami-12345678"

    # More comprehensive region config
    aws.region_config "us-west-2" do |region|
      region.ami = "ami-87654321"
      region.keypair_name = "company-west"
    end
  end
end
```

The region-specific configurations will override the top-level
configurations when that region is used. They otherwise inherit
the top-level configurations, as you would probably expect.

## Networks

Networking features in the form of `config.vm.network` are not
supported with `vagrant-aws`, currently. If any of these are
specified, Vagrant will emit a warning, but will otherwise boot
the AWS machine.

## Synced Folders

There is minimal support for synced folders. Upon `vagrant up`,
`vagrant reload`, and `vagrant provision`, the AWS provider will use
`rsync` (if available) to uni-directionally sync the folder to
the remote machine over SSH.

This is good enough for all built-in Vagrant provisioners (shell,
chef, and puppet) to work!

## Development

To work on the `vagrant-aws` plugin, clone this repository out, and use
[Bundler](http://gembundler.com) to get the dependencies:

```
$ bundle
```

Once you have the dependencies, verify the unit tests pass with `rake`:

```
$ bundle exec rake
```

If those pass, you're ready to start developing the plugin. You can test
the plugin without installing it into your Vagrant environment by just
creating a `Vagrantfile` in the top level of this directory (it is gitignored)
that uses it, and uses bundler to execute Vagrant:

```
$ bundle exec vagrant up --provider=aws
```
