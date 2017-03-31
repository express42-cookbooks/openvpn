#
# Cookbook Name:: openvpn
# Recipe:: default
#
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

class Chef
  class Recipe
    # Helpers module
    module Helpers
      def self.save_takey_databag(key_file, server_name)
        File.read(key_file)

        key_data = File.read(key_file)

        ta_item = {
          'id' => 'openvpn-ta',
          'ta' => key_data,
        }

        databag_item = Chef::DataBagItem.from_hash(
          Chef::EncryptedDataBagItem.encrypt_data_bag_item(
            ta_item,
            Chef::EncryptedDataBagItem.load_secret
          )
        )
        databag_item.data_bag("openvpn-#{server_name}")

        # Node might not have permissions to upload the data bag
        begin
          databag_item.save
        rescue Net::HTTPServerException
          Chef::Log.warn("This client does not have permissions to create the openvpn-ta data bag item in the openvpn-#{server_name} data bag!  It will need to be created manually from the contents of the /etc/openvpn/#{server_name}/keys/ta.key file.")
        end
      end
    end
  end
end
