# Vagrant AWS Provider

This is a [Vagrant](http://www.vagrantup.com) 1.1+ plugin that adds an [AWS](http://aws.amazon.com)
provider to Vagrant, allowing Vagrant to control and provision machines in
EC2 and VPC.

**NOTE:** This plugin requires Vagrant 1.1+, which is still unreleased.
Vagrant 1.1 will be released soon. In the mean time, this repository is
meant as an example of a high quality plugin using the new plugin system
in Vagrant.

## Box Format

Every provider in Vagrant must introduce a custom box format. This
provider introduces `aws` boxes. You can view an example box in
the [example_box/ directory](https://github.com/mitchellh/vagrant-aws/tree/master/example_box).
That directory also contains instructions on how to build a box.

The box format is basically just the required `metadata.json` file
along with a `Vagrantfile` that does default settings for the
provider-specific configuration for this provider.

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
