#
# Cookbook Name:: openvpn
# Recipe:: default
#
# Copyright 2013, LLC Express 42
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

server_name = node['openvpn']['server_name']
config = Chef::Mixin::DeepMerge.merge(node['openvpn']['default'].to_hash, node['openvpn'][server_name].to_hash)
server_mode = config['mode']

package 'bridge-utils' do
  only_if { server_mode == 'bridged' }
end

user 'openvpn'
group 'openvpn' do
  members ['openvpn']
end

directory "/etc/openvpn/#{server_name}" do
  owner 'root'
  group 'openvpn'
  mode '0770'
end

directory "/etc/openvpn/#{server_name}/keys" do
  owner 'root'
  group 'openvpn'
  mode '0770'
end

directory "/etc/openvpn/#{server_name}/ccd" do
  owner 'root'
  group 'openvpn'
  mode '0750'
  only_if { config['client_config_dir'] }
end

directory "/etc/openvpn/#{server_name}/tmp" do
  owner 'root'
  group 'openvpn'
  mode '0750'
  only_if { config['chroot'] }
end

if config['client_config_dir'] && config['ccd_exclusive']
  server_databags = Chef::DataBag.list(true)["openvpn-#{server_name}"]
  clients = server_databags.keys.reject { |x| x =~ /openvpn/ }

  clients.each do |client|
    client_item = Chef::EncryptedDataBagItem.load("openvpn-#{server_name}", client)
    file "/etc/openvpn/#{server_name}/ccd/#{client}" do
      owner 'root'
      group 'openvpn'
      mode '0644'
      content client_item['config'] || ''
    end
  end
end

directory '/var/log/openvpn' do
  owner 'root'
  group 'root'
  mode '0755'
end

dh_item = Chef::EncryptedDataBagItem.load("openvpn-#{server_name}", 'openvpn-dh')
ca_item = Chef::EncryptedDataBagItem.load("openvpn-#{server_name}", 'openvpn-ca')
crl_item = Chef::EncryptedDataBagItem.load("openvpn-#{server_name}", 'openvpn-crl')
server_item = Chef::EncryptedDataBagItem.load("openvpn-#{server_name}", 'openvpn-server')

ta_item = {}
if config['use_tls_auth']
  begin
    ta_item = Hash(Chef::EncryptedDataBagItem.load("openvpn-#{server_name}", 'openvpn-ta')) if config['use_tls_auth']
  rescue Net::HTTPServerException
    # Generate ta.key file since there isn't a data bag yet
    execute "openvpn --genkey --secret /etc/openvpn/#{server_name}/keys/ta.key" do
      creates "/etc/openvpn/#{server_name}/keys/ta.key"
      action :run
    end

    # move key manipulations to execution time
    ruby_block 'save ta.key content to databag' do
      block do
        Helpers.save_takey_databag("/etc/openvpn/#{server_name}/keys/ta.key", server_name)
      end
    end
  end
end

files = {
  'ca.crt' => ca_item['cert'],
  'dh.pem' => dh_item['dh'],
  'crl.pem' => crl_item['crl'],
  'server.crt' => server_item['cert'],
  'server.key' => server_item['key'],
}

files['ta.key'] = ta_item['ta'] if config['use_tls_auth'] && ta_item.include?('ta')

service_name = node['platform_family'] == 'rhel' && node['platform_version'].to_f >= 7.0 ? "openvpn@#{server_name}" : 'openvpn'

files.each do |name, content|
  file "/etc/openvpn/#{server_name}/keys/#{name}" do
    owner 'openvpn'
    group 'openvpn'
    mode '0600'
    content content
    sensitive true
    notifies :restart, "service[#{service_name}]", :delayed
  end
end

service service_name do
  action [:enable]
  only_if { service_name == 'openvpn' }
end

template "/etc/openvpn/#{server_name}.conf" do
  source 'server.conf.erb'
  variables server_name: server_name, config: config
  owner 'root'
  group 'openvpn'
  mode '0640'
  notifies :restart, "service[#{service_name}]", :delayed
end

if server_mode == 'bridged'
  brctl_bin = node['platform_family'] == 'rhel' && node['platform_version'].to_f < 7.0 ? '/usr/sbin/brctl' : '/sbin/brctl'

  template '/etc/openvpn/up.sh' do
    source 'up.sh.erb'
    owner 'root'
    group 'openvpn'
    mode '0740'
    variables(
      brctl_bin: brctl_bin
    )
    notifies :restart, "service[#{service_name}]", :delayed
  end

  template '/etc/openvpn/down.sh' do
    source 'down.sh.erb'
    owner 'root'
    group 'openvpn'
    mode '0740'
    variables(
      brctl_bin: brctl_bin
    )
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
