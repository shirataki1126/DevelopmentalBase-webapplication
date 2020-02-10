# -*- mode: ruby -*-
# vi: set ft=ruby :

# Requirement
Vagrant.require_version ">= 2.2.6"
require "json"

# Check String that is can convert integer
def isIntegerString?(string)
  Integer(string)
  return true
rescue ArgumentError
  return false
end

# Load envirioment file for this project
env = {}
if File.file?(".env")
  array = File.read(".env").split("\n")
  array.each do |line|
    unless line.start_with?("#") || line.empty?
      element = line.strip.split("=", 2)
      key_string = element[0].gsub(/\s*$/, "")
      value_string = element[1].gsub(/^\s*"(.+)"/, "\\1")
      if isIntegerString?(value_string)
        env[key_string] = value_string.to_i
      else
        env[key_string] = value_string
      end
    end
  end
end

# Define default provider
ENV["VAGRANT_DEFAULT_PROVIDER"] = env["DefaultProvider"]

Vagrant.configure("2") do |global_config|
  global_config.vm.box_check_update = true
  global_config.vm.box_download_location_trusted = true
  global_config.vm.synced_folder ".", "/vagrant", type: "rsync", disabled: true
  global_config.vagrant.plugins = ["vagrant-hostmanager", "vagrant-scp"]
  global_config.hostmanager.enabled = true
  global_config.hostmanager.manage_guest = true
  global_config.hostmanager.manage_host = true

  # VM which receive requests from clients
  global_config.vm.define "loadbalancer" do |loadbalancer|
    loadbalancer.vm.hostname = "loadbalancer"
    loadbalancer.vm.box = env["BaseBox"]
    loadbalancer.vm.box_version = env["BaseBoxVersionCondition"]
    loadbalancer.ssh.insert_key = false

    # Resolve ansible dependencies for running ansible
    loadbalancer.vm.provision "shell",
                              inline: "dnf install -y python3 python3-dnf"

    loadbalancer.vm.provider "virtualbox" do |virtualbox, override|
      virtualbox.cpus = env["LoadbalancerVmCpus"]
      virtualbox.memory = env["LoadbalancerVmMemory"]
      # In external network
      if env["IsUseHostBridgedNetworkForExternal"]
        override.vm.network "public_network"
      else
        override.vm.network "private_network",
                            ip: "#{env["IPv4NetworkAddressInExternal"]}.#{env["LoadbalancerIPv4HostAddress"]}"
      end
      # In internal network
      override.vm.network "private_network",
        ip: "#{env["IPv4NetworkAddressInInternal"]}.#{env["LoadbalancerIPv4HostAddress"]}"
    end

    loadbalancer.vm.provider "hyperv" do |hyperv, override|
      hyperv.enable_virtualization_extensions = true
      hyperv.cpus = env["LoadbalancerVmCpus"]
      hyperv.memory = env["LoadbalancerVmMemory"]
      # Select network interface
      override.vm.network "private_network", bridge: "#{env["SwitchName"]}"
      # For configuring static IPv4 address with DHCP server
      hyperv.mac = env["LoadbalancerVmNetworkMAC"]
    end
  end

  # VM which is database server
  global_config.vm.define "database" do |database|
    database.vm.hostname = "database"
    database.vm.box = env["BaseBox"]
    database.vm.box_version = env["BaseBoxVersionCondition"]
    database.ssh.insert_key = false

    # Resolve ansible dependencies for running ansible
    database.vm.provision "shell",
                          inline: "dnf install -y python3 python3-dnf"

    database.vm.provider "virtualbox" do |virtualbox, override|
      virtualbox.cpus = env["DatabaseVmCpus"]
      virtualbox.memory = env["DatabaseVmMemory"]
      # In internal network
      override.vm.network "private_network",
        ip: "#{env["IPv4NetworkAddressInInternal"]}.#{env["DatabaseIPv4HostAddress"]}"
    end

    database.vm.provider "hyperv" do |hyperv, override|
      hyperv.enable_virtualization_extensions = true
      hyperv.cpus = env["DatabaseVmCpus"]
      hyperv.memory = env["DatabaseVmMemory"]
      # Select network interface
      override.vm.network "private_network", bridge: "#{env["SwitchName"]}"
      # For configuring static IPv4 address with DHCP server
      hyperv.mac = env["DatabaseVmNetworkMAC"]
    end
  end

  # VMs that are hosts of docker containers with docker-swarm for web service
  (1..env["DockerHostVmsScale"]).each do |i|
    global_config.vm.define "dockerHost-#{i}" do |docker_host|
      docker_host.vm.hostname = "dockerHost-#{i}"
      docker_host.vm.box = env["BaseBox"]
      docker_host.vm.box_version = env["BaseBoxVersionCondition"]
      docker_host.ssh.insert_key = false

      # Resolve ansible dependencies for running ansible
      docker_host.vm.provision "shell",
                               inline: "dnf install -y python3 python3-dnf"

      docker_host.vm.provider "virtualbox" do |virtualbox, override|
        virtualbox.cpus = env["DockerHostVmsCpus"]
        virtualbox.memory = env["DockerHostVmsMemory"]
        # In internal network
        override.vm.network "private_network",
          ip: "#{env["IPv4NetworkAddressInInternal"]}.#{env["DockerHostVmsIPv4HostAddressAtFirst"] + (i - 1)}"
      end

      docker_host.vm.provider "hyperv" do |hyperv, override|
        hyperv.enable_virtualization_extensions = true
        hyperv.cpus = env["DockerHostVmsCpus"]
        hyperv.memory = env["DockerHostVmsMemory"]
        # Select network interface
        override.vm.network "private_network", bridge: "#{env["SwitchName"]}"
      end
    end
  end

  # VM which manage servers
  global_config.vm.define "manager" do |manager|
    manager.vm.hostname = "manager"
    manager.vm.box = env["BaseBox"]
    manager.vm.box_version = env["BaseBoxVersionCondition"]

    # Copy vagrant insecure_private_key for ssh to other VMs
    manager.vm.provision "file",
                         source: "#{env["VagrantHome"]}/insecure_private_key",
                         destination: "/home/vagrant/.ssh/insecure_private_key"

    manager.vm.provision "shell",
                         inline: "chmod 600 /home/vagrant/.ssh/insecure_private_key"

    # Sync ansible files with rsync
    manager.vm.synced_folder "./ansible-playbook", "/vagrant/ansible-playbook", type: "rsync", disabled: false
    manager.vm.synced_folder "./docker-compose", "/vagrant/docker-compose", type: "rsync", disabled: false

    # Resolve ansible dependencies for running ansible
    manager.vm.provision "shell",
                         inline: "dnf install -y python3 python3-dnf"

    # Run ansible
    manager.vm.provision "ansible_local" do |ansible|
      ansible.compatibility_mode = "2.0"
      ansible.playbook = "ansible-playbook/#{env["AnsiblePlaybookName"]}"
      ansible.config_file = "ansible-playbook/ansible.cfg"
      ansible.become = true
      ansible.verbose = false
      ansible.install = true
      ansible.limit = "all"
      ansible.groups = {
        "loadbalancers" => ["loadbalancer"],
        "docker_hosts" => ["dockerHost-[1:#{env["DockerHostVmsScale"]}]"],
        "databases" => ["database"],
      }

      # For nested ansible.host_vars
      database_mariadb_hostvars = {
        "root_password" => "#{env["MariadbRootPassword"]}",
        "webapp" => {
          "user_name" => "#{env["MariadbUserNameForWebapp"]}",
          "user_hostnetwork" => "#{env["IPv4NetworkAddressInInternal"]}",
          "user_password" => "#{env["MariadbUserPasswordForWebapp"]}",
          "db_name" => "#{env["MariadbDatabaseNameForWebapp"]}",
          "db_encoding" => "#{env["MariadbDatabaseEncodingForWebapp"]}",
          "db_collation" => "#{env["MariadbDatabaseCollationForWebapp"]}",
        },
      }
      manager_phpmyadmin_hostvars = {
        "blowfish_secret" => "#{env["PhpmyadminBlowfishSecret"]}",
        "server_hostname" => "database",
      }

      ansible.host_vars = {
        "loadbalancer" => {
          "site_servername" => "#{env["LoadbalancerServerName"]}",
        },
        "database" => {
          "mariadb" => "'#{database_mariadb_hostvars.to_json}'",
        },
        "manager" => {
          "site_servername" => "#{env["ManagerServerName"]}",
          "phpmyadmin" => "'#{manager_phpmyadmin_hostvars.to_json}'",
          "docker_compose_path" => "/vagrant/docker-compose",
        },
      }
    end

    manager.vm.provider "virtualbox" do |virtualbox, override|
      virtualbox.cpus = env["ManagerVmCpus"]
      virtualbox.memory = env["ManagerVmMemory"]
      # In external network
      if env["IsUseHostBridgedNetworkForExternal"]
        override.vm.network "public_network"
      else
        override.vm.network "private_network",
                            ip: "#{env["IPv4NetworkAddressInExternal"]}.#{env["ManagerIPv4HostAddress"]}"
      end
      # In internal network
      override.vm.network "private_network",
                          ip: "#{env["IPv4NetworkAddressInInternal"]}.#{env["ManagerIPv4HostAddress"]}"
    end

    manager.vm.provider "hyperv" do |hyperv, override|
      hyperv.enable_virtualization_extensions = true
      hyperv.cpus = env["ManagerVmCpus"]
      hyperv.memory = env["ManagerVmMemory"]
      # Select network interface
      override.vm.network "private_network", bridge: "#{env["SwitchName"]}"
      # For configuring static IPv4 address with DHCP server
      hyperv.mac = env["ManagerVmNetworkMAC"]
    end
  end
end
