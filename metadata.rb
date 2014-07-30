name 'chef-galera'
maintainer       "Brad Folkens"
maintainer_email "bfolkens@gmail.com"
license          "Apache 2.0"
description      "Installs Galera Cluster for MySQL"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.4.1"

depends 'apt', '>= 1.9'
depends 'yum', '~> 3.0'

recipe 'server', 'Installs Galera Cluster for MySQL'
recipe 'package_repo', 'Sets up the MariaDB official repository'
recipe 'user', 'Install mysql user and group'
recipe 'vagrant_fix', 'Vagrant host-only fix'

%w{ debian ubuntu centos fedora redhat }.each do |os|
  supports os
end