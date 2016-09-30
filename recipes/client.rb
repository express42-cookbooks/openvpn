#
# Cookbook Name:: openvpn
# Recipe:: client

# Copyright 2016, LLC Express 42
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

if node['platform_family'] == 'rhel' && node['openvpn']['install_epel']
  include_recipe 'yum-epel'
end

package 'openvpn'

user 'openvpn'
group 'openvpn' do
  members ['openvpn']
end

directory '/etc/openvpn/' do
  owner 'root'
  group 'openvpn'
  mode '0770'
end

directory '/var/log/openvpn' do
  owner 'root'
  group 'root'
  mode '0755'
end

node['openvpn']['client']['remote_servers'].each do |server_name|
  client_item = Chef::EncryptedDataBagItem.load('openvpn-client', server_name.to_s)

  files = {
    "#{server_name}-ca.crt" => client_item['ca'],
    "#{server_name}.crt" => client_item['crt'],
    "#{server_name}.key" => client_item['key'],
    "#{server_name}.conf" => client_item['conf']
  }

  service_name = node['platform_family'] == 'rhel' && node['platform_version'].to_f >= 7.0 ? "openvpn@#{server_name}" : 'openvpn'

  files.each do |name, content|
    file "/etc/openvpn/#{name}" do
      owner 'openvpn'
      group 'openvpn'
      mode '0600'
      content content
      sensitive true
      notifies :restart, "service[#{service_name}]", :delayed
    end
  end

  # needed due to SystemD before version 208-20.el7_1.5 not supporting enable for @ services
  # https://bugzilla.redhat.com/show_bug.cgi?id=1142369
  link "/etc/systemd/system/multi-user.target.wants/#{service_name}.service" do
    to '/usr/lib/systemd/system/openvpn@.service'
    link_type :symbolic
    not_if { service_name == 'openvpn' }
  end

  service service_name do
    action [:start]
  end

  service service_name do
    action [:enable]
    only_if { service_name == 'openvpn' }
  end
end
