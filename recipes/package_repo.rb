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
end
