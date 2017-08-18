source "https://rubygems.org"

group :development do
  # We depend on Vagrant for development, but we don't add it as a
  # gem dependency because we expect it to be installed within the
  # Vagrant environment itself using `vagrant plugin`.
  gem "vagrant", :git => "https://github.com/mitchellh/vagrant.git"
end

group :plugins do
  gemspec
end
