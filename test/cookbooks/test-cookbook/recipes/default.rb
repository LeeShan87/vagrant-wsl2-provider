# Test Chef recipe for WSL2 provider

log "Chef provisioner test started" do
  level :info
end

# Create a test file
file "/home/vagrant/chef-test.txt" do
  content "#{node['test']['message']}\nChef provisioner completed successfully on #{node['hostname']}\n"
  owner "vagrant"
  group "vagrant"
  mode "0644"
  action :create
end

# Install a package
package "tree" do
  action :install
end

# Create a directory
directory "/home/vagrant/chef-test" do
  owner "vagrant"
  group "vagrant"
  mode "0755"
  action :create
end

log "Chef provisioner test completed" do
  level :info
end