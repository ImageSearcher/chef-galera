Ohai::Config[:plugin_path] << node['vagrant-ohai']['plugin_path']
Chef::Log.info("vagrant ohai plugins will be at: #{node['vagrant-ohai']['plugin_path']}")

rd = remote_directory node['vagrant-ohai']['plugin_path'] do
  source 'plugins'
  owner 'root'
  group 'root'
  mode 0755
  recursive true
  action :nothing
end

rd.run_action(:create)

# only reload ohai if new plugins were dropped off OR
# node['vagrant-ohai']['plugin_path'] does not exists in client.rb
if rd.updated? || 
  !(::IO.read(Chef::Config[:config_file]) =~ /Ohai::Config\[:plugin_path\]\s*<<\s*["']#{node['vagrant-ohai']['plugin_path']}["']/)

  ohai 'custom_plugins' do
    action :nothing
  end.run_action(:reload)

end
