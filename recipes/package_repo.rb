case node['platform']
when 'centos', 'redhat', 'fedora', 'suse', 'scientific', 'amazon'
  include_recipe 'yum'

  yum_repository 'mariadb' do
    baseurl node['galera']['yum']['baseurl']
    gpgkey node['galera']['yum']['gpgkey']
    gpgcheck node['galera']['yum']['gpgcheck']
    sslverify node['galera']['yum']['sslverify']
    action :create
  end
else
  include_recipe 'apt'

  # Pin this repo to avoid upgrade conflicts
  apt_preference '00mariadb' do
    glob '*'
    pin 'release o=MariaDB Official Repository'
    pin_priority '001'
  end

  apt_repository 'mariadb' do
    uri node['galera']['apt']['uri']
    distribution node['lsb']['codename']
    keyserver node['galera']['apt']['keyserver']
    key node['galera']['apt']['key']
    action :add
  end


  bash 'prep-mariadb-repo' do
    user "root"
    code <<-EOH
      apt-get -y --force-yes install install python-software-properties
      apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
      add-apt-repository "deb  `lsb_release -c` main"
      apt-get update
    EOH
    not_if { FileTest.exists?("#{node['wsrep']['provider']}") }
  end
end
