[![Build Status](https://travis-ci.org/express42/openvpn.svg?branch=master)](https://travis-ci.org/express42/openvpn)

# Description

Installs and configures OpenVPN.

# Requirements

## Platform:

* Ubuntu
* RHEL
* CentOS

## Gems:

* knife-openvpn

# Attributes

## Default

* `node['openvpn']['server_name']` -  Defaults to `"default"`.
* `node['openvpn']['install_epel']` -  Defaults to `true`.
* `node['openvpn']['default']['remote_host']` -  Defaults to `"vpn.example.com"`.
* `node['openvpn']['default']['server_ip']` -  Defaults to `"127.0.0.1"`.
* `node['openvpn']['default']['port']` -  Defaults to `"1194"`.
* `node['openvpn']['default']['proto']` -  Defaults to `"udp"`.
* `node['openvpn']['default']['dev']` -  Defaults to `"tun"`.
* `node['openvpn']['default']['mode']` -  Defaults to `"routed"`.
* `node['openvpn']['default']['netmask']` -  Defaults to `"255.255.255.0"`.
* `node['openvpn']['default']['subnet']` -  Defaults to `"127.0.1.0"`.
* `node['openvpn']['default']['network_bridge']` -  Defaults to `"br0"`.
* `node['openvpn']['default']['network_interface']` -  Defaults to `"eth0"`.
* `node['openvpn']['default']['dhcp_start']` -  Defaults to `"127.0.0.100"`.
* `node['openvpn']['default']['dhcp_end']` -  Defaults to `"127.0.0.150"`.
* `node['openvpn']['default']['verb']` -  Defaults to `"3"`.
* `node['openvpn']['default']['push']` -  Defaults to `"[ ... ]"`.
* `node['openvpn']['default']['duplicate_cn']` -  Defaults to `"false"`.
* `node['openvpn']['default']['client_to_client']` -  Defaults to `"false"`.
* `node['openvpn']['default']['keepalive_interval']` -  Defaults to `"10"`.
* `node['openvpn']['default']['keepalive_timeout']` -  Defaults to `"60"`.
* `node['openvpn']['default']['comp_lzo']` -  Defaults to `"true"`.
* `node['openvpn']['default']['link_mtu']` -  Defaults to `"nil"`.
* `node['openvpn']['default']['tun_mtu']` -  Defaults to `"nil"`.
* `node['openvpn']['default']['cipher']` -  Defaults to `"false"`.
* `node['openvpn']['default']['redirect_gateway']` -  Defaults to `"false"`.
* `node['openvpn']['default']['push_dns_server']` -  Defaults to `"false"`.
* `node['openvpn']['default']['script_security']` -  Defaults to `"1"`.
* `node['openvpn']['default']['use_tls_auth']` -  Defaults to `"true"`.
* `node['openvpn']['default']['chroot']` -  Defaults to `"false"`.
* `node['openvpn']['default']['client_config_dir']` -  Defaults to `"false"`.
* `node['openvpn']['default']['ccd_exclusive']` -  Defaults to `"false"`.
* `node['openvpn']['default']['users']` -  Defaults to `"[ ... ]"`.
* `node['openvpn']['default']['revoked_users']` -  Defaults to `"[ ... ]"`.
* `node['openvpn']['default']['ifconfig_pool_persist']` - Defaults to `"true"`.
* `node['openvpn']['client']['remote_servers']` - Defaults to `"[ ... ]"`.

## Iptables

* `node['openvpn']['iptables']['postrouting']` -  Defaults to `true`.
* `node['openvpn']['iptables']['interface']` -  Defaults to `eth0`.

## Sysctl

* `node['openvpn']['ip_forward']` -  Defaults to `true`.

# Recipes

* openvpn::default - Installs and configures OpenVPN.
* openvpn::sysctl - Configures IP forwarding via sysctl
* openvpn::iptables - Configures postrouting via iptables
* openvpn::client - Configures client connection to server

# Server Modes

* Routed

For routed network you must define vpn ```subnet```, like in previous example

* Bridged

Bridged setup need more configuration and configured network bridge on your server

```
"default_attributes": {
  "openvpn": {
    "server_name": "office",
    "office": {
      "remote_host": "vpn.example.com",
      "server_ip": "10.90.5.5",
      "port": "443",
      "proto": "tcp",
      "dev": "tap",
      "verb": "3",
      "mode": "bridged",
      "script_security": "2",
      "dhcp_start": "10.90.5.100",
      "dhcp_end": "10.90.5.240",
      "network_bridge": "br0",
      "network_interface": "eth0"
    }
  }
}

```

See fixture cookbook in `tests/fixtures/cookbooks`.


# To-do

1. Revoke access
2. Import existing certs/keys
3. Add support for client recipe-friendly config generation


# Usage

For example you want to setup vpn server and call it ```office```

* Ensure that you have ```.chef/encrypted_data_bag_secret```.
Otherwise you can generate one with ```openssl rand -base64 512 > .chef/encrypted_data_bag_secret```

* Install knife plugin:

  ```
  gem install knife-openvpn
  ```

* Create server certificate authority, server cert/key, DH params:

  ```
  knife openvpn server create office
  ```

  ```office``` - is a name of vpn-server, there is some limitations on this: no dots, no commas, no spaces, no special symbols for reasons.

* Great, now check ```data_bags``` directory, you will find new databag ```openvpn-office``` with few items for ca, dh, cert/key pair and some openssl config. Now it is time to upload it to Chef server:

  ```
  knife data bag create openvpn-office --secret-file=.chef/encrypted_data_bag_secret
  knife data bag from file openvpn-office data_bags/openvpn-office/*
  ```

* Add ```recipe[openvpn]``` to node run_list, and override default attributes:

  ```
  "run_list": [
  "recipe[openvpn]"
  ],
  "default_attributes": {
    "openvpn": {
      "server_name": "office",
      "office": {
        "remote_host": "vpn.example.com",
        "server_ip": "10.90.5.5",
        "subnet": "10.200.1.0",
        "port": "443",
        "proto": "tcp",
        "dev": "tun",
        "verb": "3",
        "push": [
        "route 10.90.0.0 255.255.255.0",
        "route 10.90.1.0 255.255.255.0"
        ]
      }
    }
  }

  ```

* Add ```recipe[openvpn::sysctl]``` if you need to setup net.ipv4.ip_forward with this cookbook. ```node['openvpn']['ip_forward']``` should be set to ```true``` (it's ```true``` by default).

* Add ```recipe[openvpn::iptables]``` if you need to setup nat postrouting with this cookbook.

  Chef, run!

* When server is up and running we can add some users to start use it.
No moar certificate management pain:

  ```
  knife openvpn user create office john
  knife data bag from file openvpn-office data_bags/openvpn-office/john.json
  ```

* Export vpn-client data and send it to John:

  ```
  knife openvpn user export office john
  ```
resulting archive contains config (.ovpn), ca cert, John's cert and key

* Revokation of user certificate is also possible:
  ```
  knife openvpn user revoke office john
  knife data bag from file openvpn-office data_bags/openvpn-office/openvpn-crl.json
  ```

# Client configuration

* Add ```recipe[openvpn::client]``` to run_list

* Add data bag item for each server in ```node['openvpn']['client']['remote_servers']``` containing next elements (replace new lines with '\n'):

  ```
  "ca" - contents of ca.crt generated with knife-openvpn
  "crt" - contents of client's certificate
  "key" - contents of client's private key
  "conf" - contents of client's configuration
  ```

# License and Maintainer

Maintainer:: LLC Express 42 (<cookbooks@express42.com>)

License:: MIT
