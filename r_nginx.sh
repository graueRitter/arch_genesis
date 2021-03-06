#!/bin/bash
source ./common/functions

#--------------------------------------------------------------------#
# Parameters
#--------------------------------------------------------------------#
# serverURL = url nginx is to listen to. E.g.: <IP> or <fqdn>
# serverCA = certificate authority (CA) certificate
# serverCert = server public certificate signed by the CA (above)
# serverCertKey = server certificate key
#--------------------------------------------------------------------#

#--------------------------------------------------------------------#
# Defaults
#--------------------------------------------------------------------#
r_nginx_version="1.0.0"
installString=''
#--------------------------------------------------------------------#

#--------------------------------------------------------------------#
# Functions
#--------------------------------------------------------------------#
function print_usage
{
	echo '/* -- Help: --*/'
	echo 'Installs nginx web service with root file location /srv/http/root/'
	echo ''
	echo 'Syntax: r_nginx.sh <configuration file>' >&2 ;
	echo "Where configuration file defines the following variables:"
	echo "  \$serverURL => url of root web page which can be either an IP, or fqdn"
	echo "  [optional - if all below are null then self signed certificate will be created]"
	echo "  \$serverCertCA => CA certificate - must end in '.crt'"
	echo "  \$serverCert => server certificate"
	echo "  \$serverCertKey => server certificate key"
	echo '/* -- End Help -- */'
}

function print_option_file_variables
{
	echo '/* -- Validating options file  --*/'
	echo "  Web server root url: $serverURL"
	echo "  Web server certificate CA: $serverCertCA"
	echo "  Web server certificate: $serverCert"
	echo "  Web server certificate key: $serverCertKey"
}

function rollback
{
	# to clean up after failed installation attempt
	# not currently in use - future expansion
	echo -e "\e[0;31mRolling back \e[0m"
}

function configure_SSL
{
	# only if serverCert, serverCertCA, and serverCertKey not specified
	if [[ $serverCert == '' && $serverCertCA == '' && $serverCertKey == '' ]] ;
	then
		echo -e "\e[0;32mCreating self signed SSL certificates \e[0m"
		current_task='Create self signed SSL certificates'
		fqdn=$serverURL
		sudo openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
		-keyout /etc/ssl/private/$fqdn.key -out /etc/ssl/certs/$fqdn.crt \
		-subj "/CN=$fqdn"
		exit_on_error $? "$current_task"
		if [ ! -f /etc/ssl/certs/dhparam.pem ]
		then
			sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096
			exit_on_error $? "$current_task"
		fi
	else
		echo -e "\e[0;32mUsing specified or existing SSL certificates \e[0m"
		current_task='Using specified or existing SSL certificates'
		if [ ! -f "/etc/certs/$serverCert" ]; then
			cp -p $serverCert /etc/ssl/certs/
			exit_on_error $? "$current_task"
		fi
		if [ ! -f "/etc/certs/$serverCertKey" ]; then
			cp -p $serverCertKey /etc/ssl/certs/
			exit_on_error $? "$current_task"
		fi
		# Add CA
		if [ ! -f "/etc/certs/$serverCertCA" ]; then
			current_task='Installing CA certificate into trusted source'
			cp -p $serverCertCA /etc/ca-certificates/trust-source/anchors/
			exit_on_error $? "$current_task"
			chmod ugo-wx /etc/ca-certificates/trust-source/anchors/$serverCertCA
			exit_on_error $? "$current_task"
			chmod ugo+r /etc/ca-certificates/trust-source/anchors/$serverCertCA
			exit_on_error $? "$current_task"
		fi
		trust extract-compat
		exit_on_error $? "$current_task"
	fi
}
#--------------------------------------------------------------------#

#--------------------------------------------------------------------#
# Initialise parameters
#--------------------------------------------------------------------#

# Note that we use `"$@"' to let each command-line parameter expand to a
# separate word. The quotes around `$@' are essential!
# We need TEMP as the `eval set --' would nuke the return value of getopt.
TEMP=`getopt --options h --long help -n 'v_svr_base.sh' -- "$@"`

# check for valid number of parameters
#  - note: count includes both parameter name and value, so (parameters*2)
if [[ "$#" -ne 1 ]]
then
	print_usage ;
	exit 1 ;
fi

# terminate if error - not sure what error though
if [ $? != 0 ] ; then echo "Terminating" >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

# process arguments
while true ; do
	case "$1" in
		-h|--help)
			print_usage
			exit 1 ;;
		--) shift ; break ;;
		*) echo "Internal error!" ; exit 1 ;;
	esac
done
#--------------------------------------------------------------------#

echo -e "\e[0;34mStarting r_nginx.sh v$r_nginx_version\e[0m"
echo ''

#--------------------------------------------------------------------#
# Load options
#--------------------------------------------------------------------#
. $1
#--------------------------------------------------------------------#

#--------------------------------------------------------------------#
# Pre flight checks
#--------------------------------------------------------------------#
# ensure running as root - exit if not
# check nginx data is on separate partition
# check mount options: noexec, nosuid, etc.
# check if nginx already installed - offer nginx-mainline
# note comment in https://wiki.archlinux.org/index.php/Nginx#Installation
#  on module compatibility between nginx and nginx-mainline
#  - should this script install nginx instead?
# check openssl installed

# check if root privileges
if [[ $(id -u) -ne 0 ]] ; then echo -e "\e[0;31mPlease run as root\e[0m" ; exit 1 ; fi

# check mount options - should contain nosuid and noexec
srvMount=`cat /etc/fstab |egrep -v "^[[:blank:]]*(#|$)" | grep 'srv'`
if [[ $srvMount != *"nosuid"* || $srvMount != *"noexec"* ]]  ;
then
	echo -e "\e[0;33mWarning: html root not mounted without noexec and/or nosuid options\e[0m" ;
	# should not show as may be part of "/" filesystem: echo "  /etc/fstab:"
	# should not show as may be part of "/" filesystem: cat /etc/fstab | grep '/srv' ;
	echo ''
else
	echo -e "\e[0;32mCheck noexec and nosuid mount option: Ok\e[0m" ;
	echo ''
fi

# check for nginx-mainline
pacman -Q nginx-mainline &>/dev/null
if [ $? -eq 0 ]
then
	echo 'nginx is installed' ;
	echo 'Exiting nginx install script';
	exit 1;
else
	installString="$installString nginx-mainline"
fi

# check if php-fpm already installed
pacman -Q php-fpm &>/dev/null
if [ $? -eq 0 ]
then
	echo 'php-fpm is installed, skipping';
	echo 'Exiting nginx install script';
else
	installString="$installString php-fpm"
fi

# check if openssl
pacman -Q openssl &>/dev/null
if [ $? -eq 0 ]
then
	echo 'openssl is installed, skipping' ;
else
	installString="$installString openssl"
fi

# ask human to verify variables
print_option_file_variables
echo ''
echo -e "\e[0;31mAbout to install nginx web server (https://$serverURL) to /srv/html/root \e[0m"
echo -e "\e[0;31mCtrl-c to abort, [Enter] key to proceed \e[0m"
read
echo ''
#--------------------------------------------------------------------#

#--------------------------------------------------------------------#
# Install
#--------------------------------------------------------------------#
# potential issues here:
#  https://unix.stackexchange.com/questions/52277/pacman-option-to-assume-yes-to-every-question
#  - will break if pacman asks for a selection. Perform manual '-syu' first then just '-S'?
if [ ! -z "${installString}" ];
then
	echo -e "\e[32mInstalling packages: $installString \e[0m"
	current_task="Installing packages"
	pacman --noconfirm -S $installString
	# or pacman -Syu --noconfirm $installString ?
	exit_on_error $? "$current_task"
fi
#--------------------------------------------------------------------#


#--------------------------------------------------------------------#
# Configure
#--------------------------------------------------------------------#
configure_SSL

echo -e "\e[32mConfiguring nginx and php-fpm \e[0m"
current_task="Configuring nginx"
#------------------------------- nginx ------------------------------#
# copy default nginx root site configuration
mkdir -p /etc/nginx/sites-available
exit_on_error $? "$current_task"
backup_file "/etc/nginx/sites-available/www-root"
touch /etc/nginx/sites-available/www-root
exit_on_error $? "$current_task"
chmod go-wx /etc/nginx/sites-available/www-root
exit_on_error $? "$current_task"
chmod go+r /etc/nginx/sites-available/www-root
exit_on_error $? "$current_task"
echo "#--------------------------------------#" > /etc/nginx/sites-available/www-root
exit_on_error $? "$current_task"
echo "# Installed by r_nginx.sh v$r_nginx_version" >> /etc/nginx/sites-available/www-root
exit_on_error $? "$current_task"
echo "#--------------------------------------#" >> /etc/nginx/sites-available/www-root
exit_on_error $? "$current_task"
echo "" >> /etc/nginx/sites-available/www-root
exit_on_error $? "$current_task"
cat r_nginx/www-root >> /etc/nginx/sites-available/www-root
exit_on_error $? "$current_task"
fqdn=$serverURL
exit_on_error $? "$current_task"
sed -e s@"HOSTNAME"@"$fqdn"@g /etc/nginx/sites-available/www-root > /etc/nginx/sites-available/www-root.tmp \
&& mv --force /etc/nginx/sites-available/www-root.tmp /etc/nginx/sites-available/www-root
exit_on_error $? "$current_task"

# enable default site
mkdir -p /etc/nginx/sites-enabled
exit_on_error $? "$current_task"
if [ ! -f "/etc/nginx/sites-enabled/www-root" ];
then
	ln -s /etc/nginx/sites-available/www-root /etc/nginx/sites-enabled/www-root
	exit_on_error $? "$current_task"
fi
# default nginx confguration
backup_file "/etc/nginx/nginx.conf"
touch /etc/nginx/nginx.conf
exit_on_error $? "$current_task"
chmod go-wx /etc/nginx/nginx.conf
exit_on_error $? "$current_task"
chmod go+r /etc/nginx/nginx.conf
exit_on_error $? "$current_task"
echo "#--------------------------------------#" > /etc/nginx/nginx.conf
exit_on_error $? "$current_task"
echo "# Installed by r_nginx.sh v$r_nginx_version" >> /etc/nginx/nginx.conf
exit_on_error $? "$current_task"
echo "#--------------------------------------#" >> /etc/nginx/nginx.conf
exit_on_error $? "$current_task"
echo "" >> /etc/nginx/nginx.conf
exit_on_error $? "$current_task"
cat r_nginx/nginx.conf >> /etc/nginx/nginx.conf
exit_on_error $? "$current_task"

# nginx does not always start in default 90 seconds for systemd service
# - three minutes empirically determined to work
# - from core dump may have something to do with waiting for entropy?
mkdir -p /etc/systemd/system/nginx.service.d ;
exit_on_error $? "$current_task"
backup_file "/etc/systemd/system/nginx.service.d/override.conf"
echo "#--------------------------------------#" > /etc/systemd/system/nginx.service.d/override.conf
exit_on_error $? "$current_task"
echo "# Installed by r_nginx.sh v$r_nginx_version" >> /etc/systemd/system/nginx.service.d/override.conf
exit_on_error $? "$current_task"
echo "#--------------------------------------#" >> /etc/systemd/system/nginx.service.d/override.conf
exit_on_error $? "$current_task"
echo "" >> /etc/systemd/system/nginx.service.d/override.conf
exit_on_error $? "$current_task"
echo '[Service]' >> /etc/systemd/system/nginx.service.d/override.conf
exit_on_error $? "$current_task"
echo 'TimeoutStartSec=300' >> /etc/systemd/system/nginx.service.d/override.conf
exit_on_error $? "$current_task"

# run nginx as unprivileged - not working, still permission errors
# - e.g. binding to 0.0.0.0:80
##if [ -f /etc/systemd/system/nginx.service.d/override.conf ]
##then
##	mv /etc/systemd/system/nginx.service.d/override.conf /etc/systemd/system/nginx.service.d/override.conf.original ;
##else
##	mkdir -p /etc/systemd/system/nginx.service.d ;
##fi
##echo "#--------------------------------------#" > /etc/systemd/system/nginx.service.d/override.conf
##echo "# Installed by r_nginx.sh v$r_nginx_version" >> /etc/systemd/system/nginx.service.d/override.conf
##echo "#--------------------------------------#" >> /etc/systemd/system/nginx.service.d/override.conf
##echo "" >> /etc/systemd/system/nginx.service.d/override.conf
##cat r_nginx/override.conf >> /etc/systemd/system/nginx.service.d/override.conf
##chown http:http /etc/nginx/ssl/server.key
##chown --recursive http:http /var/log/nginx

# move default web site to root location
mkdir -p /srv/html/root
exit_on_error $? "$current_task"
cp -a /usr/share/nginx/html/* /srv/html/root
exit_on_error $? "$current_task"

#----------------------------- PHP-FPM ------------------------------#
# default php-fpm confguration
current_task='Configuring php-fpm'
backup_file "/etc/php/php-fpm.d/www.conf"
backup_file "/etc/php/php-fpm.d/www-root.conf"
echo ";--------------------------------------;" > /etc/php/php-fpm.d/www-root.conf
exit_on_error $? "$current_task"
echo "; Installed by r_nginx.sh v$r_nginx_version" >> /etc/php/php-fpm.d/www-root.conf
exit_on_error $? "$current_task"
echo ";--------------------------------------;" >> /etc/php/php-fpm.d/www-root.conf
exit_on_error $? "$current_task"
echo "" >> /etc/php/php-fpm.d/www-root.conf
exit_on_error $? "$current_task"
cat r_nginx/www-root.conf >> /etc/php/php-fpm.d/www-root.conf
exit_on_error $? "$current_task"
chmod go-wx /etc/php/php-fpm.d/www-root.conf
exit_on_error $? "$current_task"
chmod go+r /etc/php/php-fpm.d/www-root.conf
exit_on_error $? "$current_task"

#------------------------------ nftables ----------------------------#
current_task='Configuring nftables firewall'
backup_file "/etc/nftables.conf"
echo "" >> /etc/nftables.conf
exit_on_error $? "$current_task"
echo "" >> /etc/nftables.conf
exit_on_error $? "$current_task"
echo "#--------------------------------------#" >> /etc/nftables.conf
exit_on_error $? "$current_task"
echo "# Added by r_nginx.sh v$r_nginx_version" >> /etc/nftables.conf
exit_on_error $? "$current_task"
echo "#--------------------------------------#" >> /etc/nftables.conf
exit_on_error $? "$current_task"
echo "" >> /etc/nftables.conf
exit_on_error $? "$current_task"
echo "# allow http and https incoming" >> /etc/nftables.conf
exit_on_error $? "$current_task"
echo "add rule inet filter input tcp dport http accept" >> /etc/nftables.conf
exit_on_error $? "$current_task"
echo "#IPv6: add rule ip6 filter input tcp dport http accept" >> /etc/nftables.conf
exit_on_error $? "$current_task"
echo "add rule inet filter input tcp dport https accept" >> /etc/nftables.conf
exit_on_error $? "$current_task"
systemctl restart nftables
exit_on_error $? "$current_task"
#--------------------------------------------------------------------#


#--------------------------------------------------------------------#
# Enable and start
#--------------------------------------------------------------------#
echo -e "\e[32mEnabling and starting web server services \e[0m"
current_task='Enabling and starting services'
systemctl enable nginx
exit_on_error $? "$current_task"
systemctl start nginx
exit_on_error $? "$current_task"
systemctl status nginx
exit_on_error $? "$current_task"
systemctl enable php-fpm
exit_on_error $? "$current_task"
systemctl start php-fpm
exit_on_error $? "$current_task"
systemctl status php-fpm
exit_on_error $? "$current_task"
#--------------------------------------------------------------------#
