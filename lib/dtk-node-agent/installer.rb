#
# Copyright (C) 2010-2016 dtk contributors
#
# This file is part of the dtk project.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
module DTK
  module NodeAgent
    class Installer
      require 'facter'

      # read configuration
      CONFIG = eval(File.open(File.expand_path('../config/install.config', File.dirname(__FILE__))) {|f| f.read })

      # get OS facts
      @osfamily     = Facter.value('osfamily').downcase
      @osname       = Facter.value('operatingsystem')
      @osmajrelease = Facter.value('operatingsystemmajrelease')
      @osarch       = Facter.value('architecture')
      @distcodename = Facter.value('lsbdistcodename')

      def self.run(argv)
        require 'optparse'
        require 'fileutils'
        require 'dtk-node-agent/version'

        @@options = parse(argv)

        unless Process.uid == 0
          puts "dtk-node-agent must be started with root/sudo privileges."
          exit(1)
        end

        if @osfamily == 'debian'
          # set up apt and install packages
          shell "apt-get update --fix-missing"
          shell "apt-get install -y build-essential wget curl git libicu-dev zlib1g-dev"
          # install upgrades
          Array(CONFIG[:upgrades][:debian]).each do |package|
            shell "apt-get install -y #{package}"
          end
          shell "wget http://apt.puppetlabs.com/puppetlabs-release-#{@distcodename}.deb"
          puts "Installing Puppet Labs repository..."
          shell "dpkg -i puppetlabs-release-#{@distcodename}.deb"
          puts "Installing Puppet Labs repository..."
          shell "dpkg -i puppetlabs-release-#{@distcodename}.deb"
          # install logstash forwarder
          logstash_forwarder_url = CONFIG[:logstash_forwarder_deb64]
          logstash_forwarder_package = logstash_forwarder_url.rpartition('/').last
          shell "wget #{logstash_forwarder_url}"
          puts "Installing logstash-forwarder"
          shell "dpkg -i #{logstash_forwarder_package}"
          shell "apt-get update"
          shell "rm puppetlabs-release-#{@distcodename}.deb #{logstash_forwarder_package}"
          # pin down the puppetlabs apt repo
          FileUtils.cp("#{base_dir}/src/etc/apt/preferences.d/puppetlabs", "/etc/apt/preferences.d/puppetlabs")
        elsif @osfamily == 'redhat'
          shell "yum -y install yum-utils wget curl libicu-devel zlib-devel"
          # do a full upgrade
          shell "yum -y update"
          case @osmajrelease
          when "5"
            shell "rpm -ivh #{CONFIG[:puppetlabs_el5_rpm_repo]}"
            @osarch == 'X86_64' ? (shell "rpm -ivh #{CONFIG[:rpm_forge_el5_X86_64_repo]}") : (shell "rpm -ivh #{CONFIG[:rpm_forge_el5_i686_repo]}")
          # 20xx is the major release naming pattern of Amazon Linux
          when "6", "n/a", "2015", "2014", "2016"
            shell "rpm -ivh #{CONFIG[:puppetlabs_el6_rpm_repo]}"
            @osarch == 'X86_64' ? (shell "rpm -ivh #{CONFIG[:rpm_forge_el6_X86_64_repo]}") : (shell "rpm -ivh #{CONFIG[:rpm_forge_el6_i686_repo]}")
            shell "yum-config-manager --disable rpmforge-release"
            shell "yum-config-manager --enable rpmforge-extras"
          when "7"
            shell "rpm -ivh #{CONFIG[:puppetlabs_el7_rpm_repo]}"
          else
            puts "#{@osname} #{@osmajrelease} is not supported. Exiting now..."
            exit(1)
          end
          shell "yum -y install git"
          # install upgrades
          Array(CONFIG[:upgrades][:redhat]).each do |package|
            shell "yum -y install #{package}"
            shell "yum -y update #{package}"
          end
          # install ec2-run-user-data init script
          # but only if the machine is running on AWS
          if `curl -m 5 -sI http://169.254.169.254/latest/meta-data/`.include? '200 OK'
            FileUtils.cp("#{base_dir}/src/etc/init.d/ec2-run-user-data", "/etc/init.d/ec2-run-user-data") unless File.exist?("/etc/init.d/ec2-run-user-data")
            set_init("ec2-run-user-data")
          end
          # install logstash-forwarder
          puts "Installing logstash-forwarder"
          shell "rpm -ivh #{CONFIG[:logstash_forwarder_rpm64]}"
          FileUtils.cp("#{base_dir}/src/etc/init.d/logstash-forwarder.rpm.init", "/etc/init.d/logstash-forwarder")
          set_init("logstash-forwarder")
        else
          puts "Unsuported OS for automatic agent installation. Exiting now..."
          exit(1)
        end

        puts "Installing additions Puppet..."
        install_additions

        puts "Installing DTK Arbiter"
        install_arbiter

        puts "Disabling apt-daily service"
        disable_apt_daily if @lsbdistcodename == 'xenial'
      end

      private

      def self.parse(argv)
        options = {}
        parser = OptionParser.new do |opts|
          opts.banner = <<-BANNER
          usage:

          dtk-node-agent [-p|--puppet-version] [-v|--version]
          BANNER
          opts.on("-d",
            "--debug",
            "enable debug mode")  { |v| options[:debug] = true }
          opts.on_tail("-v",
            "--version",
            "Print the version and exit.") do
            puts ::DtkNodeAgent::VERSION
            exit(0)
          end
          opts.on_tail("-h",
            "--help",
            "Print this help message.") do
            puts parser
            exit(0)
          end
        end

        parser.parse!(argv)

        options

      rescue OptionParser::InvalidOption => e
        $stderr.puts e.message
        exit(12)
      end

      def self.shell(cmd)
        puts "running: #{cmd}" if @@options[:debug]
        output = `#{cmd}`
        puts output if @@options[:debug]
        if $?.exitstatus != 0
          puts "Executing command \`#{cmd}\` failed"
          puts "Command output:"
          puts output
        end
      end

      def self.install_additions
        # create puppet group
        shell "groupadd puppet" unless `grep puppet /etc/group`.include? "puppet"
        # create necessary dirs
        [ '/var/log/puppet/',
          '/var/lib/puppet/lib/puppet/indirector',
          '/etc/puppet/modules',
          '/usr/share/dtk/modules'
          ].map! { |p| FileUtils.mkdir_p(p) unless File.directory?(p) }
        # copy puppet libs
        FileUtils.cp_r(Dir.glob("#{base_dir}/puppet_additions/puppet_lib_base/puppet/indirector/*"), "/var/lib/puppet/lib/puppet/indirector/")
        # copy dtk/r8 puppet module
        FileUtils.cp_r(Dir.glob("#{base_dir}/puppet_additions/modules/*"), "/usr/share/dtk/modules/")
        # symlink dtk/r8 puppet module
        FileUtils.ln_sf("/usr/share/dtk/modules/dtk", "/etc/puppet/modules/")
        FileUtils.ln_sf("/usr/share/dtk/modules/r8", "/etc/puppet/modules/")
      end

      def self.base_dir
        File.expand_path('../..', File.dirname(__FILE__))
      end

      def self.is_systemd
        File.exist?("/etc/systemd/system")
      end

      def self.set_init(script)
        shell "chmod +x /etc/init.d/#{script}"
        if @osfamily == 'debian'
          shell "update-rc.d #{script} defaults"
        elsif @osfamily == 'redhat'
          shell "chkconfig --level 345 #{script} on"
          # in case of a systemd system, reload the daemons
          if is_systemd
            shell "systemctl daemon-reload"
            shell "systemctl enable #{script}.service"
          end
        end
      end

      def self.install_arbiter
        arbiter_branch = CONFIG[:arbiter_branch] || 'stable'
        shell "git clone -b #{arbiter_branch} https://github.com/dtk/dtk-arbiter /usr/share/dtk/dtk-arbiter"
        Dir.chdir "/usr/share/dtk/dtk-arbiter"
        shell "bundle install --without development"
        puts "Installing dtk-arbiter init script"
        FileUtils.ln_sf("/usr/share/dtk/dtk-arbiter/etc/#{@osfamily}.dtk-arbiter.init", "/etc/init.d/dtk-arbiter")
        # copy the service file, since systemd doesn't follow symlinks
        FileUtils.cp("/usr/share/dtk/dtk-arbiter/etc/systemd.dtk-arbiter.service", "/etc/systemd/system/dtk-arbiter.service") if is_systemd
        set_init("dtk-arbiter")
        puts "Installing dtk-arbiter monit config."
        monit_cfg_path = (@osfamily == 'debian') ? "/etc/monit/conf.d" : "/etc/monit.d"
        set_init("monit")
        logrotate_cfg_path = "/usr/share/dtk/dtk-arbiter/etc/dtk-arbiter.logrotate"
        FileUtils.ln_sf("/usr/share/dtk/dtk-arbiter/etc/dtk-arbiter.monit", "#{monit_cfg_path}/dtk-arbiter") if File.exist?(monit_cfg_path)
        FileUtils.cp(logrotate_cfg_path, "/etc/logrotate.d/dtk-arbiter") if File.exist?(logrotate_cfg_path)
      end

      def self.disable_apt_daily
        shell "systemctl disable apt-daily.service"
      end

    end
  end
end