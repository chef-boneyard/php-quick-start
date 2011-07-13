#
# Author:: Seth Chisamore <schisamo@opscode.com>
# Cookbook Name:: mediawiki
# Recipe:: db_bootstrap
#
# Copyright 2011, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# THIS RECIPE IS DESTRUCTIVE.  It will drop all existing database tables and reload them.

app = data_bag_item("apps", "mediawiki")

if node.run_list.roles.include?(app["database_master_role"][0])
  dbm = node
else
  dbm = search(:node, "role:#{app["database_master_role"][0]} AND chef_environment:#{node.chef_environment}").first
end

db = app['databases'][node.chef_environment]

cookbook_file "#{Chef::Config[:file_cache_path]}/schema.sql" do
  source "schema.sql"
  mode 0755
  owner "root"
  group "root"
end

db_host = (dbm.attribute?('cloud') ? dbm['cloud']['local_ipv4'] : dbm['ipaddress'])

execute "db_bootstrap" do
  command "/usr/bin/mysql -u #{db['username']} -p#{db['password']} -h #{db_host} #{db['database']} < #{Chef::Config[:file_cache_path]}/schema.sql"
  action :run
  notifies :create, "ruby_block[remove_mediawiki_bootstrap]", :immediately
end

ruby_block "remove_mediawiki_bootstrap" do
  block do
    Chef::Log.info("Database Bootstrap completed, removing the destructive recipe[mediawiki::db_bootstrap]")
    node.run_list.remove("recipe[mediawiki::db_bootstrap]") if node.run_list.include?("recipe[mediawiki::db_bootstrap]")
  end
  action :nothing
end