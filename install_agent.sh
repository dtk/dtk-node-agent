#!/usr/bin/env bash

# check if script was kicked off with root/sudo privileges
if [ "$(whoami)" != "root" ]; then
	echo "Not running as root. Exiting..."
	exit 0
fi

# get OS info
function getosinfo()
{
	export osname=`lsb_release -d | awk '{print $2}' | sed 's+NAME="++g'`
	export codename=`lsb_release -c | awk '{print $2}'`
	export release=`lsb_release -r | awk '{print $2}'`
}

base_dir="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# update PATH just in case
export PATH=$PATH:/sbin:/usr/sbin

# read the arguments
args="$*"

# Wait for machines with cloud-init to finish with boot process
if [[ -d /var/lib/cloud ]]; then
  timeout 180 /bin/bash -c \
  'until stat /var/lib/cloud/instance/boot-finished 2>/dev/null; do echo waiting ...; sleep 1; done'
fi

# check package manager used on the system and install appropriate packages/init scripts
if [[ `command -v apt-get` ]]; then
	apt-get update  --fix-missing
	apt-get -y install python-software-properties build-essential wget curl lsb-release logrotate
	getosinfo
	if [[ ${osname} == 'Ubuntu' ]]; then
		# add the git core ppa
		yes | sudo add-apt-repository ppa:git-core/ppa
		# add the ruby ppa for releases older than 16.04
		[[ ${release} != '16.04' ]] && yes | sudo add-apt-repository ppa:brightbox/ruby-ng
		apt-get update
		wget -q "http://dtk-storage.s3.amazonaws.com/puppet-omnibus_3.8.7%2Bfpm0_amd64.deb" -O puppet-omnibus.deb
    # install backported kernel for docker if on 12.04
    if [[ ${release} == '12.04' ]]; then
      apt-get -y install linux-image-generic-lts-trusty
    fi
	elif [[ ${osname} == 'Debian' ]]; then
		wget -q "http://dtk-storage.s3.amazonaws.com/puppet-omnibus_3.6.2%2Bfpm0_amd64.debian.deb" -O puppet-omnibus.deb
	fi
	if [[ ${codename} == 'squeeze' ]]; then
		echo "deb http://backports.debian.org/debian-backports squeeze-backports main" > /etc/apt/sources.list.d/squeeze-backports.list
		apt-get update
		apt-get -y install git/squeeze-backports
	fi;
	apt-get -y install git ruby2.3 ruby2.3-dev
	# install puppet-omnibus	
	dpkg --force-overwrite -i puppet-omnibus.deb
	apt-get -y -f install
	rm -rf puppet-omnibus.deb
elif [[ `command -v yum` ]]; then
	# install ruby and git
	yum -y groupinstall "Development Tools"
	yum -y install wget redhat-lsb logrotate libyaml
	# install puppet-omnibus
	getosinfo
	if [[ ${release:0:1} == 5 ]]; then
		wget -q http://dtk-storage.s3.amazonaws.com/puppet-omnibus-3.3.2.fpm0-1.x86_64.el5.rpm -O puppet-omnibus.rpm
	elif [[ ${release:0:1} == 6 ]] || [[ ${release:0:1} == 7 ]] || [[ ${osname} == 'Amazon' ]];then
    # use curl here as a workaround for wget segmentation fault on amazon-linux
		curl http://dtk-storage.s3.amazonaws.com/puppet-omnibus-3.8.7.fpm0-1.x86_64.rpm -o puppet-omnibus.rpm
	fi
	yum -y --nogpgcheck localinstall puppet-omnibus.rpm
	rm -rf puppet-omnibus.rpm
	# ruby install
	if [[ ${osname} == 'Amazon' ]]; then
		# remove all ruby 2.0 packages to prevent conflicts
		yum -y remove ruby*20*
		yum -y install ruby23 ruby23-devel
	elif [[ ${release:0:1} == 7 ]]; then
		rpm -ivh https://s3.amazonaws.com/dtk-storage/ruby-2.3.4-1.el7.centos.x86_64.rpm
	fi
else
	echo "Unsuported OS for automatic agent installation. Exiting now..."
	exit 1
fi;

# install gems for ruby-provider
gem install grpc --no-rdoc --no-ri
gem install aws-sdk-iam -v 1.13.0 --no-rdoc --no-ri
gem install aws-sdk-ec2 -v 1.67.0 --no-rdoc --no-ri
gem install aws-sdk-kms -v 1.13.0 --no-rdoc --no-ri
gem install byebug --no-rdoc --no-ri

export PATH=/opt/puppet-omnibus/embedded/bin/:/opt/puppet-omnibus/bin/:$PATH

# remove any existing gems
[[ `ls ${base_dir}/*.gem 2>/dev/null` ]] && rm ${base_dir}/*.gem
# install the dtk-node-agent gem
cd ${base_dir}
gem uninstall -aIx puppet
gem build ${base_dir}/dtk-node-agent.gemspec
gem install posix-spawn -v 0.3.13 --no-rdoc --no-ri
gem install ${base_dir}/dtk-node-agent*.gem --no-rdoc --no-ri

if [[ ${args} =~ "--no-arbiter" ]]; then
  no_arbiter="--no-arbiter"
fi

# run the gem
dtk-node-agent -d $no_arbiter

# remove puppet.conf if it exists
[[ -f /etc/puppet/puppet.conf ]] && rm /etc/puppet/puppet.conf

[[ ! -f /etc/logrotate.d/puppet ]] && cp ${base_dir}/src/etc/logrotate.d/puppet /etc/logrotate.d/puppet

# install docker
# if [[ ${osname} == 'Amazon' ]];then
# 	yum update -y && yum install docker -y;
# else
#   curl -sSL https://get.docker.com/ | sh
# fi

# remove root ssh files
rm -f /root/.ssh/id_rsa
rm -f /root/.ssh/id_rsa.pub 
rm -f /root/.ssh/known_hosts

# remove puppet logs
rm -f /var/log/puppet/*

if [[ ${args} =~ "--sanitize" ]]; then
  # sanitize the AMI (creating unique ssh host keys will be handled by the cloud-init package)
  find /root /home -name ".*history" -exec rm -f {} \;
  find /root /home /etc -name "authorized_keys" -exec rm -f {} \;
fi;
