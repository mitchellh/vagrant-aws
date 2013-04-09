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
