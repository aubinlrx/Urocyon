# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION ||= 2
confDir = $confDir ||= File.expand_path(File.dirname(__FILE__))

configPath = confDir + "/Urocyon.yaml"
afterScriptPath = confDir + "/scripts/after.sh"
aliasesPath = confDir + "/aliases"

require File.expand_path(File.dirname(__FILE__) + '/scripts/urocyon.rb')

Vagrant.require_version '>= 2.1.0'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu/xenial64" # Ubuntu 16.04

  if File.exist?(aliasesPath)
    config.vm.provision "file", source: aliasesPath, destination: "/tmp/bash_aliases"
    config.vm.provision "shell" do |s|
      s.inline = "awk '{ sub(\"\r$\", \"\"); print }' /tmp/bash_aliases > /home/vagrant/.bash_aliases"
    end
  end

  if File.exist?(configPath)
    settings = YAML::load(File.read(configPath))
  else
    abort "No configuration file supplied"
  end

  Urocyon.configure(config, settings)

  if File.exist?(afterScriptPath)
    config.vm.provision :shell, path: afterScriptPath, privileged: false, keep_color: true
  end
end
