# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.box = "jessie64"
  config.vm.box_url = "https://downloads.sourceforge.net/project/vagrantboxjessie/debian80.box"

  config.ssh.forward_agent = true

  # Settings for the vm
  config.vm.define :machine do |machine|
    machine.vm.network :private_network, ip: "10.0.0.2"
    machine.vm.synced_folder ".", "/vagrant", owner: "www-data", group: "www-data"

    machine.vm.provider "virtualbox" do |v|
        v.memory = 2048
    end

    machine.vm.provision "shell", inline: "sudo apt-get update && sudo apt-get install -y puppet"

    # Use puppet for provisioning
    machine.vm.provision :puppet do |puppet|
      puppet.manifests_path = "support/puppet/manifests"
      puppet.module_path = "support/puppet/modules"
      puppet.manifest_file  = "default.pp"
      puppet.options = [
        '--verbose',
        #'--debug'
      ]
    end

  end

end
