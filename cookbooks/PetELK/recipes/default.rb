#
# Cookbook Name:: PetELK
# Recipe:: default
#
# The MIT License (MIT)
#
# Copyright (c) 2016 Jeff Geiger
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# With copious chunks of Chef copied from the RockNSM Project. /Hat Tip


log 'branding' do
  message '
===========================================


  ______           _______ _       _    _
 (_____ \     _   (_______) |     | |  / )
  _____) )___| |_  _____  | |     | | / /
 |  ____/ _  )  _)|  ___) | |     | |< <
 | |   ( (/ /| |__| |_____| |_____| | \ \
 |_|    \____)\___)_______)_______)_|  \_)


           Feed it your data.


===========================================
'
  level :warn
  action :nothing
end

#######################################################
################# OS & Version Check ##################
#######################################################
# Only CentOS or RHEL, because I said so.
# Testing multiple distros? Ain't nobody got time for that.
Chef::Log.debug(node['platform_family'])
Chef::Log.debug(node['platform_version'])

if node['platform_family'] != 'rhel'
  Chef::Log.fatal('This Cookbook is only meant for RHEL/CENTOS 7')
end

# Die if it's not CentOS/RHEL 7
raise if node['platform_family'] != 'rhel'
raise if not node['platform_version'] =~ /^7./

######################################################
################# Data Directory #####################
######################################################
# This is where your data will go, duh.
directory '/data' do
  mode '0755'
  owner 'root'
  group 'root'
  action :create
end

#######################################################
##################### Memory Info #####################
#######################################################
## Grab memory total from Ohai
total_memory = node['memory']['total']

## Ohai reports node[:memory][:total] in kB, as in "921756kB"
mem = total_memory.split("kB")[0].to_i / 1048576 # in GB

# Let's set a sane default in case ohai has decided to screw us.
node.run_state['es_mem'] = 4

if mem < 64
  # For systems with less than 32GB of system memory, we'll use half for Elasticsearch
  node.run_state['es_mem'] = mem / 2
else
  # Elasticsearch recommends not using more than 32GB for Elasticearch
  node.run_state['es_mem'] = 32
end

# We'll use es_mem later to do a "best effort" elasticsearch configuration


######################################################
################### Configure Time ###################
######################################################
# Not 100% necessary, but it will help to make sure your
# time-series data looks "right".
package 'chrony' do
  action :install
end

execute 'set_time_zone' do
  command '/usr/bin/timedatectl set-timezone UTC'
  not_if '/usr/bin/timedatectl | grep -q "Time zone.*UTC"'
end

execute 'enable_ntp' do
  command '/usr/bin/timedatectl set-ntp yes'
  not_if '/usr/bin/timedatectl | grep -q "NTP enabled.*yes"'
end


######################################################
################# Configure Hostname #################
######################################################
execute 'set_hostname' do
  command "echo -e '127.0.0.2\t#{node.normal['host_fqdn']}\t#{node.normal['host_short']}' >> /etc/hosts"
end

execute 'set_system_hostname' do
  command "hostnamectl set-hostname #{node.normal['host_fqdn']}"
end

#######################################################
#################### Install EPEL #####################
#######################################################
package 'epel-release' do
  action :install
  ignore_failure true
end

execute 'install_epel' do
  command 'rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm'
  not_if '[ $(rpm -qa epel-release | wc -l) -gt 0 ]'
end

execute 'import_epel_key' do
  command 'rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7'
  only_if '[ -f /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7 ]'
end

#######################################################
############### Install Elastic Repos #################
#######################################################
yum_repository 'elasticsearch-5.x' do
  description 'Elasticsearch repository for 5.x packages'
  baseurl 'https://artifacts.elastic.co/packages/5.x-prerelease/yum'
  gpgcheck false
  gpgkey 'https://artifacts.elastic.co/GPG-KEY-elasticsearch'
  action :create
end

execute 'import_ES_key' do
  command 'rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch'
end


#######################################################
################## Build YUM Cache ####################
#######################################################
execute 'yum_makecache' do
  command 'yum makecache fast'
end

#######################################################
################## Schwack Packages ###################
#######################################################
package 'firewalld' do
  action :remove
end

package 'postfix' do
  action :remove
end

#######################################################
############### Install Core Packages #################
#######################################################
package ['java-1.8.0-openjdk-headless', 'elasticsearch', 'logstash', 'kibana', 'git', 'vim', 'nano', 'jq', 'nginx', 'net-tools', 'lsof', 'htop', 'bats', 'nmap-ncat', 'GeoIP-update', 'GeoIP-devel', 'GeoIP', 'unzip']


######################################################
################ Configure Elasticsearch #############
######################################################
#Create Data Directory
directory '/data/elasticsearch' do
  mode '0755'
  owner 'elasticsearch'
  group 'elasticsearch'
  action :create
end

template '/etc/elasticsearch/jvm.options' do
  source 'elasticsearch_jvm.options.erb'
end

template '/etc/sysconfig/elasticsearch' do
  source 'sysconfig_elasticsearch.erb'
end

template '/usr/lib/sysctl.d/elasticsearch.conf' do
  source 'sysctl.d_elasticsearch.conf.erb'
end

template '/etc/elasticsearch/elasticsearch.yml' do
  source 'etc_elasticsearch.yml.erb'
end

template '/etc/security/limits.d/elasticsearch.conf' do
  source 'etc_limits.d_elasticsearch.conf.erb'
end

template '/usr/local/bin/es_cleanup.sh' do
  source 'es_cleanup.sh.erb'
  mode '0755'
end

execute 'set_es_memlock' do
  command 'sed -i "s/.*LimitMEMLOCK.*/LimitMEMLOCK=infinity/g" /usr/lib/systemd/system/elasticsearch.service'
  not_if {File.readlines('/usr/lib/systemd/system/elasticsearch.service').grep(/^LimitMEMLOCK=infinity/).size > 0}
end

execute 'reread_sysctl' do
  command '/sbin/sysctl --system'
end

service 'elasticsearch' do
  action [ :enable, :start ]
end


######################################################
#################### Configure GeoIP #################
######################################################
template '/etc/GeoIP.conf' do
  source 'GeoIP.conf.erb'
  notifies :run, "execute[run_geoipupdate]", :immediately
end

execute 'run_geoipupdate' do
  command '/usr/bin/geoipupdate'
  action :nothing
  notifies :run, "bash[link_geoip_files]", :immediately
end

bash 'link_geoip_files' do
  code <<-EOH
    ln -s /usr/share/GeoIP/GeoLiteCity.dat /usr/share/GeoIP/GeoIPCity.dat
    ln -s /usr/share/GeoIP/GeoLiteCountry.dat /usr/share/GeoIP/GeoIPCountry.dat
    ln -s /usr/share/GeoIP/GeoLiteASNum.dat /usr/share/GeoIP/GeoIPASNum.dat
    ln -s /usr/share/GeoIP/GeoLiteCityv6.dat /usr/share/GeoIP/GeoIPCityv6.dat
 EOH
  action :nothing
end


######################################################
################## Configure Kibana ##################
######################################################
service 'kibana' do
  action [ :enable, :start ]
end

bash 'set_kibana_replicas' do
  code <<-EOH
   local ctr=0
  while ! $(ss -lnt | grep -q ':9200'); do sleep 1; ctr=$(expr $ctr + 1); if [ $ctr -gt 30 ]; then exit; fi; done
  curl -XPUT localhost:9200/_template/kibana-config -d ' {
   "order" : 0,
   "template" : ".kibana",
   "settings" : {
     "index.number_of_replicas" : "0",
     "index.number_of_shards" : "1"
   },
   "mappings" : { },
   "aliases" : { }
  }'
EOH
end


######################################################
################ Configure ES Plugins ################
######################################################
bash '' do
  code <<-EOH
  cd /usr/share/elasticsearch/
  bin/elasticsearch-plugin install x-pack
  cd /usr/share/kibana/
  bin/kibana-plugin install x-pack
  for i in elasticsearch kibana; do systemctl restart $i; done
  while ! $(ss -lnt | grep -q ':9200'); do sleep 1; ctr=$(expr $ctr + 1); if [ $ctr -gt 30 ]; then exit; fi; done
  while ! $(ss -lnt | grep -q ':5601'); do sleep 1; ctr=$(expr $ctr + 1); if [ $ctr -gt 30 ]; then exit; fi; done
EOH
end



######################################################
################## Configure Logstash ################
######################################################
directory '/data/dumpfolder' do
  mode '0755'
  owner 'root'
  group 'root'
  action :create
end

directory '/var/cache/logstash' do
  mode '0755'
  owner 'logstash'
  group 'logstash'
  action :create
end

template '/etc/logstash/conf.d/files.conf' do
  source 'files.conf.erb'
end

service 'logstash' do
  action [ :enable, :start ]
end


######################################################
#################### Configure Cron ##################
######################################################
cron 'es_cleanup_cron' do
  hour '0'
  minute '1'
  command '/usr/local/bin/es_cleanup.sh >/dev/null 2>&1'
end


######################################################
######################## NGINX #######################
######################################################
#!!!REVISIT!!!#
template '/etc/nginx/conf.d/petelk.conf' do
  source 'petelk.conf.erb'
end

template '/etc/nginx/nginx.conf' do
  source 'nginx.conf.erb'
end

file '/etc/nginx/conf.d/default.conf' do
  action :delete
end

file '/etc/nginx/conf.d/example_ssl.conf' do
  action :delete
end

execute 'enable_nginx_connect_selinux' do
  command 'setsebool -P httpd_can_network_connect 1'
  not_if 'getsebool httpd_can_network_connect | grep -q "on$"'
end

service 'nginx' do
  action [ :enable, :start ]
end


#######################################################
######################## EL FIN #######################
#######################################################
execute 'done' do
  command "echo -e '\n\nSUCCESS!!!\n\n\n♪~ ᕕ(ᐛ)ᕗ\n\n\n'"
  notifies :write, "log[branding]", :delayed
end
