#
# Cookbook Name:: galera
# Recipe:: galera_server
#
# Copyright 2012, Severalnines AB.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe 'chef-galera::vagrant_fix'

include_recipe 'chef-galera::user'
include_recipe 'chef-galera::package_repo'


# Install galera packages
%w(rsync galera mariadb-galera-server mariadb-client).each do |package_name|
  package package_name
end

# Ensure my.conf file is correctly configured
template "my.cnf" do
  path "#{node['mysql']['conf_dir']}/my.cnf"
  source "my.cnf.erb"
  owner "mysql"
  group "mysql"
  mode "0644"
#  notifies :restart, "service[mysql]", :delayed
end

service "mysql" do
  supports :restart => true, :start => true, :stop => true
  service_name node['mysql']['servicename']
  action :nothing
end


# Bootstrapping the cluster

my_ip = node['ipaddress']
init_host = node['galera']['init_node']
sync_host = init_host

# Try to sync with a random node in the cluster, falling back the the init host
hosts = node['galera']['galera_nodes']
Chef::Log.info "init_host = #{init_host}, my_ip = #{my_ip}, hosts = #{hosts}"
# TOOD: run on configure lifecycle event?
# if File.exists?("#{install_flag}") && hosts != nil && hosts.length > 0
#   i = 0
#   begin
#     sync_host = hosts[rand(hosts.count)]
#     i += 1
#     if (i > hosts.count)
#       # no host found, use init node/host
#       sync_host = init_host
#       break
#     end
#   end while my_ip == sync_host
# end

# Update the address of the members of the cluster in the my.cnf file
wsrep_cluster_address = 'gcomm://'
if hosts != nil && hosts.length > 0
  wsrep_cluster_address = hosts.map {|h| "#{h}:#{node['wsrep']['port']}" }.join(',')
end

Chef::Log.info "wsrep_cluster_address = #{wsrep_cluster_address}"
bash "set-wsrep-cluster-address" do
  user "root"
  code <<-EOH
  sed -i 's#.*wsrep_cluster_address.*=.*#wsrep_cluster_address=#{wsrep_cluster_address}#' #{node['mysql']['conf_dir']}/my.cnf
  EOH
  # TODO: basically - run on lifecycle events 'configure' or 'install'
  # only_if { (node['galera']['update_wsrep_urls'] == 'yes') || !FileTest.exists?("#{install_flag}") }
end

# If we are the initial node then we need to start the cluster
service "init-cluster" do
  service_name node['mysql']['servicename']
  supports :start => true
  start_command "service #{node['mysql']['servicename']} start --wsrep-cluster-address=gcomm://"
  action [:enable, :start]
  only_if { my_ip == init_host }
end

# Sleep to ensure the init host is dont with its Chef run incase we are provisioning a whole custer at once
if my_ip != init_host && !File.exists?("#{install_flag}")
  Chef::Log.info "Joiner node sleeping #{node['xtra']['sleep']} seconds to make sure donor node is up..."
  sleep(node['xtra']['sleep'])
  Chef::Log.info "Joiner node cluster address = gcomm://#{sync_host}:#{node['wsrep']['port']}"
end

# Start MySQL service
service "join-cluster" do
  service_name node['mysql']['servicename']
  supports :restart => true, :start => true, :stop => true
  action [:enable, :start]
  only_if { my_ip != init_host }
end

# Ensure we have joined the cluster and wait until the sync is complete
bash "wait-until-synced" do
  user "root"
  code <<-EOH
    state=0
    cnt=0
    until [[ "$state" == "4" || "$cnt" > 5 ]]
    do
      state=$(#{node['mysql']['mysql_bin']} -uroot -h127.0.0.1 -e "SET wsrep_on=0; SHOW GLOBAL STATUS LIKE 'wsrep_local_state'")
      state=$(echo "$state"  | tr '\n' ' ' | awk '{print $4}')
      cnt=$(($cnt + 1))
      sleep 1
    done
  EOH
  only_if { my_ip == init_host }
end

# Ensure the wresp user has appropriate permissions
bash "set-wsrep-grants-mysqldump" do
  user "root"
  code <<-EOH
    #{node['mysql']['mysql_bin']} -uroot -h127.0.0.1 -e "GRANT ALL ON *.* TO '#{node['wsrep']['user']}'@'%' IDENTIFIED BY '#{node['wsrep']['password']}'"
    #{node['mysql']['mysql_bin']} -uroot -h127.0.0.1 -e "SET wsrep_on=0; GRANT ALL ON *.* TO '#{node['wsrep']['user']}'@'127.0.0.1' IDENTIFIED BY '#{node['wsrep']['password']}'"
  EOH
  only_if { my_ip == init_host && (node['wsrep']['sst_method'] == 'mysqldump') && !FileTest.exists?("#{install_flag}") }
end

# Help secure the default MySQL installation
bash "secure-mysql" do
  user "root"
  code <<-EOH
    #{node['mysql']['mysql_bin']} -uroot -h127.0.0.1 -e "DROP DATABASE IF EXISTS test; DELETE FROM mysql.db WHERE DB='test' OR DB='test\\_%'"
    #{node['mysql']['mysql_bin']} -uroot -h127.0.0.1 -e "UPDATE mysql.user SET Password=PASSWORD('#{node['mysql']['root_password']}') WHERE User='root'; DELETE FROM mysql.user WHERE User=''; DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1'); FLUSH PRIVILEGES;"
  EOH
  only_if { my_ip == init_host && (node['galera']['secure'] == 'yes') && !FileTest.exists?("#{install_flag}") }
end
