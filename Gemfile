source "https://rubygems.org"

gemspec

group :development do
  # We depend on Vagrant for development, but we don't add it as a
  # gem dependency because we expect to be installed within the
  # Vagrant environment itself using `vagrant plugin`.
  gem "vagrant", :git => "https://github.com/mitchellh/vagrant.git"
  gem 'iniparse', '~> 1.4', '>= 1.4.2'
end

group :plugins do
  gem "vagrant-aws" , path: "."
end
