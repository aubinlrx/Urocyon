class Urocyon
  def self.configure(config, settings)
    ENV['VAGRANT_DEFAULT_PROVIDER'] = settings['provider'] || 'virtualbox'

    script_dir = File.dirname(__FILE__)

    # Allow SSH agent forward from box
    config.ssh.forward_agent = true

    # Configure Verify Host Key
    if settings.has_key?('verify_host_key')
      config.ssh.verify_host_key = settings['verify_host_key']
    end

    # Configure The Box
    config.vm.define settings['name'] ||= 'urocyon'
    config.vm.box = settings['box'] ||= 'urocyon'
    config.vm.box_version = settings['version'] ||= '>= 6.3.0'
    config.vm.host_name = settings['hostname'] ||= 'hostname'

    # Configure a private Network IP
    if settings['ip'] != 'autonetwork'
      config.vm.network :private_network, ip: settings['ip'] ||= '192.168.10.10'
    else
      config.vm.network :private_network, ip: '0.0.0.0', auto_network: true
    end

    # Configure additionnal networks
    if settings.has_key?('networks')
      settings['networks'].each do |network|
        config.vm.network network['type'], ip: network['ip'], bridge: network['bridge'] ||= nil, netmask: network['netmask'] ||= '255.255.255.0' 
      end
    end

    # Config for Virtualbox
    config.vm.provider 'virtualbox' do |vb|
      vb.name = settings['name'] ||= 'urocyon'
      vb.customize ['modifyvm', :id, '--memory', settings['memory'] ||= '2048']
      vb.customize ['modifyvm', :id, '--cpus', settings['cpus'] ||= '1']
      vb.customize ['modifyvm', :id, '--natdnsproxy1', 'on']
      vb.customize ['modifyvm', :id, '--natdnshostresolver1', settings['natdnshostresolver'] ||= 'on']
      vb.customize ['modifyvm', :id, '--ostype', 'Ubuntu_64']
    end

    # Override SSH port on the host
    if settings.has_key?('default_ssh_port')
      config.vm.network :forwarded_port, guest: 22, host: settings['default_ssh_port'], auto_correct: false, id: "ssh"
    end

    # Default Port Forwarding
    default_ports = {
      80 => 8080,
      443 => 44300,
      3306 => 33060,
      3000 => 3000
    }

    # Use default port forwarding unless overriden
    unless settings.has_key?('default_ports') && settings['default_ports'] == false
      default_ports.each do |guest, host|
        unless settings['ports'].any? { |mapping| mapping['guest'] == guest }
          config.vm.network 'forwarded_port', guest: guest, host: host, auto_correct: true
        end
      end
    end

    # Add Custom Ports From Configuration
    if settings.has_key?('ports')
      settings['ports'].each do |port|
        config.vm.network 'forwarded_port', guest: port['guest'], host: port['host'], protocol: port['protocol'], auto_correct: true
      end
    end

    # Copy additionnal SSH Private Keys to the box
    if settings.include?('keys')
      if settings['keys'].to_s.length.zero?
        puts 'Check your urocyon.yaml file, you have no private key(s) specified.'
        exit
      end

      settings['keys'].each do |key|
        if File.exist?(File.expand_path(key))
          config.vm.provision 'shell' do |s|
            s.privileged = false
            s.inline = "echo \"$1\" > /home/vagrant/.ssh/$2 && chmod 600 /home/vagrant/.ssh/$2"
            s.args = [File.read(File.expand_path(key)), key.split('/').last]
          end
        end
      end

    else
      puts 'Check your Urocyon.yaml file, the path to your private key does not exist.'
      exit
    end

    # Register All of the configured Shared folders
    if settings.include?('folders')
      settings['folders'].each do |folder|
        if File.exist?(File.expand_path(folder['map']))
          mount_opts = []

          if ENV['VAGRANT_DEFAULT_PROVIDER'] == 'hyperv'
            folder['type'] = 'smb'
          end

          if folder['type'] == 'nfs'
            mount_opts = folder['mount_options'] ? folder['mount_options'] : ['actimeo=1', 'nolock']
          elsif folder['type'] == 'smb'
            mount_opts = folder['mount_options'] ? folder['mount_options'] : ['vers=3.02', 'mfsymlinks']

            smb_creds = { 'smb_host': folder['smb_host'], 'smb_username': folder['smb_username'], 'smb_password': folder['smb_password'] }
          end

          # For b/w compatibility keep separate 'mount_ops', but merge with options
          options = (folder['options'] || {}).merge({ mount_options: mount_opts }).merge(smb_creds || {})

          # Double-splat (**) operator only works with symbol keys, so convert
          options.keys.each { |k| options[k.to_sym] = options.delete(k) }

          config.vm.synced_folder folder['map'], folder['to'], type: folder['type'] ||= nil, **options

          # Bindfs support to fix shared folder (NFS) permission issue on Mac
          if folder['type'] == 'nfs' && Vagrant.has_plugin('vagrant-bindfs')
            config.bindfs.bind_folder folder['to'], folder['to']
          end
        
        else
          config.provision :shell do |s|
            s.inline = ">&2 echo \"Unable to mount one of your folders. Please check your folders in Urocyon.yaml\""
          end
        end
      end
    end

    # Setup Environment variables
    if settings.has_key?('env_variables')
      settings['env_variables'].each do |var|
  
        config.vm.provision :shell do |s|
          s.inline = "echo \"\n# Set Urocyon Environment Variable\nexport $1=$2\" >> /home/vagrant/.profile"
          s.args = [var['key'], var['value']]
        end
      end
    end

    # Copy user file over to the VM
    if settings.has_key?('copy')
      settings['copy'].each do |file|
        config.vm.provision :file do |f|
          f.source = File.expand_path(file['from'])
          f.destination = file['to'].chomp('/') + '/' + file['from'].split('/').last
        end
      end
    end

    # Configure Server Environment Variables
    config.vm.provision :shell do |s|
      s.name = 'Clear Env Variables'
      s.path = script_dir + '/clear-env-variables.sh'
    end

    # Setup / Install essentials packages
    config.vm.provision :shell do |s|
      s.name = 'Setup essential packages'
      s.path = script_dir + '/setup.sh'
    end

    # Install Mysql if Necessary
    if settings.has_key?('mysql57') && settings['mysql57']
      config.vm.provision :shell do |s|
        s.name = 'Install MySQL'
        s.path = script_dir + '/install-mysql57.sh'
        s.args = [settings['mysql57']]
      end
    end

    # Install Ruby/RVM
    if settings.has_key?('ruby') && settings['rvm']
      config.vm.provision :shell do |s|
        s.name = 'Install RVM'
        s.privileged = false
        s.path = script_dir + '/install-rvm.sh'
      end

      config.vm.provision :shell do |s|
        s.name = 'Install Ruby'
        s.path = script_dir + '/install-ruby.sh'
        s.privileged = false
        s.args = [settings['ruby']]
      end
    end

    # Install NodeJS
    if settings.has_key?('nodejs') && settings['nodejs']
      config.vm.provision :shell do |s|
        s.name = 'Install NodeJS'
        s.path = script_dir + '/install-nodejs.sh'
      end
    end

    # Install Redis
    if settings.has_key?('redis') && settings['redis']
      config.vm.provision :shell do |s|
        s.name = 'Install Redis'
        s.path = script_dir + '/install-redis.sh'
      end
    end

    # Install imagemagick
    if settings.has_key?('imagemagick') && settings['imagemagick']
      config.vm.provision :shell do |s|
        s.name = 'Install imagemagick packages'
        s.path = script_dir + '/install-imagemagick.sh'
      end
    end

    # Add entry to etc/hosts
    if settings.has_key?('etc_hosts') && settings['etc_hosts']
      settings['etc_hosts'].each do |host|
        config.vm.provision :shell do |s|
          s.name = 'Add ' + host['host_name'] + ' to etc/hosts'
          s.privileged = true
          s.path = script_dir + '/update-etc-hosts.sh'
          s.args = [host['ip_address'], host['name']]
        end
      end

      # Cleanup after installations
      config.vm.provision :shell do |s|
        s.name = 'Cleanup installations'
        s.path = script_dir + '/cleanup.sh'
      end
    end

  end
end