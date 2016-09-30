name             'openvpn'
maintainer       'LLC Express 42'
maintainer_email 'cookbooks@express42.com'
license          'MIT'
description      'Installs and configures OpenVPN.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.7'
source_url 'https://github.com/express42-cookbooks/openvpn' if respond_to?(:source_url)
issues_url 'https://github.com/express42-cookbooks/openvpn/issues' if respond_to?(:issues_url)

recipe 'openvpn::default', 'Installs and configures OpenVPN.'
recipe 'openvpn::sysctl', 'Configures IP forwarding via sysctl.'
recipe 'openvpn::iptables', 'Configures postrouting via iptables.'

%w(
  amazon
  centos
  debian
  fedora
  redhat
  scientific
  ubuntu
).each do |os|
  supports os
end

depends 'iptables'
depends 'sysctl'
depends 'yum-epel'
