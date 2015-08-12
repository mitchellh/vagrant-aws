# 0.6.1

* Added configurable instance state check interval

# 0.6.0 (December 13, 2014)

* Support static Elastic IP addresses.
* Support for creating AMIs with the `vagrant package`

# 0.5.0 (June 22, 2014)

* Support for associating public IPs for VMs inside of VPCs (GH
  [#219](https://github.com/mitchellh/vagrant-aws/pull/219), GH
  [#205](https://github.com/mitchellh/vagrant-aws/issues/205))
* Bug-fix for per region configs with `associate_public_ip` (GH
  [#237](https://github.com/mitchellh/vagrant-aws/pull/237))
* rsyncing folders uses `--delete` flag to better emulate "real shared folders
  (GH [#194](https://github.com/mitchellh/vagrant-aws/pull/194))
* fog gem version bumped to 1.22 (GH [#253](https://github.com/mitchellh/vagrant-aws/pull/253))
* Simple ELB support (GH [#88](https://github.com/mitchellh/vagrant-aws/pull/88),
  GH [#238](https://github.com/mitchellh/vagrant-aws/pull/238))

# 0.4.1 (December 17, 2013)

* Update fog.io to 1.18.0
* Fix sync folder user permissions (GH #175)
* Fix vagrant < 1.3.0 provisioner compatibility (GH #173)
* Add vagrant 1.4.0 multiple SSH key support (GH #172)
* Fix EIP deallocation bug (GH #164)
* Add (per shared folder) rsync exclude flag (GH #156)

# 0.4.0 (October 11, 2013)

* Handle EIP allocation error (GH #134)
* Implement halt and reload (GH #31)
* rsync ignores Vagrantfile
* warn if none of the security groups allows incoming SSH
* bump fog.io to 1.15.0
* Fix rsync on windows (GH #77)
* Add `ssh_host_attribute` config (GH #143)

# 0.3.0 (September 2, 2013)

* Parallelize multi-machine up on Vagrant 1.2+
* Show proper configuration errors if an invalid configuration key
  is used.
* Request confirmation on `vagrant destroy`, like normal VirtualBox + Vagrant.
* If user data is configured, output is shown on "vagrant up" that
  it is being set.
* Add EIP support (GH #65)
* Add block device mapping support (GH #93)
* README improvements (GH #120)
* Fix missing locale message (GH #73)
* SyncFolders creates hostpath if it doesn't exist and `:create` option is set (GH #17)
* Add IAM Instance Profile support (GH #68)
* Add shutdown behavior support (GH #125,#131)

# 0.2.2 (April 18, 2013)

* Fix crashing bug with incorrect provisioner arguments.

# 0.2.1 (April 16, 2013)

* Got rid of extranneous references to old SSH settings.

# 0.2.0 (April 16, 2013)

* Add support for `vagrant ssh -c` [GH-42]
* Ability to specify a timeout for waiting for instances to become ready. [GH-44]
* Better error message if instance didn't become ready in time.
* Connection can now be done using IAM profiles. [GH-41]

# 0.1.3 (April 9, 2013)

* The `AWS_ACCESS_KEY` and `AWS_SECRET_KEY` will be used if available
  and no specific keys are set in the Vagrantfile. [GH-33]
* Fix issues with SSH on VPCs, the correct IP is used. [GH-30]
* Exclude the ".vagrant" directory from rsync.
* Implement `:disabled` flag support for shared folders. [GH-29]
* `aws.user_data` to specify user data on the instance. [GH-26]

# 0.1.2 (March 22, 2013)

* Choose the proper region when connecting to AWS. [GH-9]
* Configurable SSH port. [GH-13]
* Support other AWS-compatible API endpoints with `config.endpoint`
  and `config.version`. [GH-6]
* Disable strict host key checking on rsync so known hosts aren't an issue. [GH-7]

# 0.1.1 (March 18, 2013)

* Up fog dependency for Vagrant 1.1.1

# 0.1.0 (March 14, 2013)

* Initial release.
