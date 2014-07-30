# Create MySQL group and user
group "mysql" do
end

user "mysql" do
  gid "mysql"
  comment "MySQL server"
  system true
  shell "/bin/false"
end
