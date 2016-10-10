# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "bento/centos-7.2"
  config.vm.network "forwarded_port", guest: 80, host: 8000
  config.vm.network "forwarded_port", guest: 9200, host: 9200
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "9216"
  end

  config.vm.provision "chef_solo" do |chef|
    chef.log_level = "info"
    chef.cookbooks_path = "cookbooks" # path to your cookbooks
    chef.add_recipe "PetELK"
  end

end
