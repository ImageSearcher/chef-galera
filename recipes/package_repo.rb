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

  yum_repository 'percona' do
    baseurl node['percona']['yum']['baseurl']
    gpgkey node['percona']['yum']['gpgkey']
    gpgcheck node['percona']['yum']['gpgcheck']
    sslverify node['percona']['yum']['sslverify']
    action :create
  end
else
  include_recipe 'apt'

  # Pin repos to avoid upgrade conflicts
  apt_preference '00mariadb' do
    glob '*'
    pin 'release o=MariaDB Official Repository'
    pin_priority '001'
  end

  apt_preference '00percona' do
    glob '*'
    pin 'release o=Percona Repository'
    pin_priority '001'
  end

  apt_repository 'mariadb' do
    uri node['galera']['apt']['uri']
    distribution node['lsb']['codename']
    keyserver node['galera']['apt']['keyserver']
    key node['galera']['apt']['key']
    components node['galera']['apt']['components']
    action :add
  end

  apt_repository 'percona' do
    uri node['percona']['apt']['uri']
    distribution node['lsb']['codename']
    keyserver node['percona']['apt']['keyserver']
    key node['percona']['apt']['key']
    components node['percona']['apt']['components']
    action :add
  end
end
