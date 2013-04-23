# 0.3.0 (unreleased)

* Parallelize multi-machine up on Vagrant 1.2+
* Show proper configuration errors if an invalid configuration key
  is used.
* Request confirmation on `vagrant destroy`, like normal VirtualBox + Vagrant.

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
