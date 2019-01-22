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
r_nginx_version="0.1.0"
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
	echo "  \$serverCertCA => CA certificate - must end in '.crt'"
	echo "  \$serverCert => server certificate"
	echo "  \$serverCertKey => server certificate key"
	echo '/* -- End Help -- */'
}

function print_option_file_variables
{
	echo '/* -- Validating options file ... --*/'
	echo "  Web server root url: $serverURL"
	echo "  Web server certificate CA: $serverCertCA"
	echo "  Web server certificate: $serverCert"
	echo "  Web server certificate key: $serverCertKey"
}

function rollback
{
	# to clean up after failed installation attempt
	echo -e "\e[0;31mRolling back ...\e[0m"
}

function configure_SSL
{
	# only if serverCert, serverCertCA, and serverCertKey not specified
	if [[ $serverCert == '' && $serverCertCA == '' && $serverCertKey == '' ]] ;
	then
		echo -e "\e[0;32mCreating self signed certificates ...\e[0m"
		fqdn=`hostname -f`
		sudo openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
		-keyout /etc/ssl/private/$fqdn.key -out /etc/ssl/certs/$fqdn.crt \
		-subj "/CN=$fqdn"
		sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096
	else
		echo -e "\e[0;32mUsing specified certificates ...\e[0m"
		if [ ! -f "/etc/certs/$serverCert" ]; then
			cp -p $serverCert /etc/ssl/certs/
		fi
		if [ ! -f "/etc/certs/$serverCertKey" ]; then
			cp -p $serverCertKey /etc/ssl/certs/
		fi
		# Add CA
		if [ ! -f "/etc/certs/$serverCertCA" ]; then
			cp -p $serverCertCA /etc/ca-certificates/trust-source/anchors/
			chmod ugo-wx /etc/ca-certificates/trust-source/anchors/$serverCertCA
			chmod ugo+r /etc/ca-certificates/trust-source/anchors/$serverCertCA
		fi
		trust extract-compat
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
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

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
        echo -e "\e[0;33mWarning: html root not mounted without noexec and/or nosuid options:\e[0m" ;
        echo "  /etc/fstab:"
        cat /etc/fstab | grep '/srv' ;
else
        echo -e "\e[0;32mCheck noexec and nosuid mount option: Ok\e[0m" ;
fi

# check for nginx or nginx-mainline
pacman -Q nginx &>/dev/null
if [ $? -eq 0 ]
then
	echo 'nginx is installed, nginx-mainline is the recommended version' ;
	echo 'skipping nginx-mainline install...' ;
else
	pacman -Q nginx-mainline &>/dev/null
	if [ $? -eq 0 ]
	then
		echo 'nginx-mainline is installed' ;
		echo 'skipping nginx-mainline install...' ;
	else
		installString="$installString nginx-mainline"
	fi
fi

# check if php-fpm already installed
pacman -Q php-fpm &>/dev/null
if [ $? -eq 0 ]
then
	echo 'php-fpm is installed, skipping...' ;
else
	installString="$installString php-fpm"
fi

# check if openssl
pacman -Q openssl &>/dev/null
if [ $? -eq 0 ]
then
	echo 'openssl is installed, skipping...' ;
else
	installString="$installString openssl"
fi

# ask human to verify variables
print_option_file_variables
echo ''
echo -e "\e[0;31mAbout to install nginx web server (https://$serverURL) to /srv/html/root ...\e[0m"
echo -e "\e[0;31mCtrl-c to abort, [Enter] key to proceed ...\e[0m"
read
echo ''
#--------------------------------------------------------------------#

#--------------------------------------------------------------------#
# Install
#--------------------------------------------------------------------#
# potential issues here:
#  https://unix.stackexchange.com/questions/52277/pacman-option-to-assume-yes-to-every-question
#  - will break if pacman asks for a selection. Perform manual '-syu' first then just '-S'?
echo -e "\e[32mInstalling: $installString ...\e[0m"
pacman --noconfirm -S $installString
# or pacman -Syu --noconfirm $installString ?

#--------------------------------------------------------------------#


#--------------------------------------------------------------------#
# Configure
#--------------------------------------------------------------------#
echo -e "\e[32mConfiguring nginx and php-fpm ...\e[0m"

#------------------------------- nginx ------------------------------#
# copy default nginx root site configuration
mkdir -p /etc/nginx/sites-available
if [ -f /etc/nginx/sites-available/www-root ]
then
	mv /etc/nginx/sites-available/www-root /etc/nginx/sites-available/www-root.original ;
fi
touch /etc/nginx/sites-available/www-root
chmod go-wx /etc/nginx/sites-available/www-root
chmod go+r /etc/nginx/sites-available/www-root
echo "#--------------------------------------#" > /etc/nginx/sites-available/www-root
echo "# Installed by r_nginx.sh v$r_nginx_version" >> /etc/nginx/sites-available/www-root
echo "#--------------------------------------#" >> /etc/nginx/sites-available/www-root
echo "" >> /etc/nginx/sites-available/www-root
cat r_nginx/www-root >> /etc/nginx/sites-available/www-root
# change default URL to host's fqdn
configure_SSL
fqdn=$(hostname -f)
sed -e s@"HOSTNAME"@"$fqdn"@g /etc/nginx/sites-available/www-root > /etc/nginx/sites-available/www-root.tmp \
&& mv --force /etc/nginx/sites-available/www-root.tmp /etc/nginx/sites-available/www-root

# enable default site
mkdir -p /etc/nginx/sites-enabled
ln -s /etc/nginx/sites-available/www-root /etc/nginx/sites-enabled/www-root

# default nginx confguration
if [ -f /etc/nginx/nginx.conf ]
then
	mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.original ;
fi
touch /etc/nginx/nginx.conf
chmod go-wx /etc/nginx/nginx.conf
chmod go+r /etc/nginx/nginx.conf
echo "#--------------------------------------#" > /etc/nginx/nginx.conf
echo "# Installed by r_nginx.sh v$r_nginx_version" >> /etc/nginx/nginx.conf
echo "#--------------------------------------#" >> /etc/nginx/nginx.conf
echo "" >> /etc/nginx/nginx.conf
cat r_nginx/nginx.conf >> /etc/nginx/nginx.conf

# nginx does not always start in default 90 seconds for systemd service
# - three minutes empirically determined to work
# - from core dump may have something to do with waiting for entropy?
if [ -f /etc/systemd/system/nginx.service.d/override.conf ]
then
	mv /etc/systemd/system/nginx.service.d/override.conf /etc/systemd/system/nginx.service.d/override.conf.original ;
else
	mkdir -p /etc/systemd/system/nginx.service.d ;
fi
echo "#--------------------------------------#" > /etc/systemd/system/nginx.service.d/override.conf
echo "# Installed by r_nginx.sh v$r_nginx_version" >> /etc/systemd/system/nginx.service.d/override.conf
echo "#--------------------------------------#" >> /etc/systemd/system/nginx.service.d/override.conf
echo "" >> /etc/systemd/system/nginx.service.d/override.conf
echo '[Service]' >> /etc/systemd/system/nginx.service.d/override.conf
echo 'TimeoutStartSec=300' >> /etc/systemd/system/nginx.service.d/override.conf

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
cp -a /usr/share/nginx/html/* /srv/html/root
# add php information page - Really? Security risk?
#cp r_nginx/phpinfo.php /srv/html/root
# secure directory
# breaks web browsing when not running as unpriviliged as above: chown --recursive http:http /srv/html/root
# breaks web browsing when not running as unpriviliged as above: chmod --recursive go-rwx /srv/html/root

#----------------------------- PHP-FPM ------------------------------#
# default php-fpm confguration
if [ -f /etc/php/php-fpm.d/www.conf ]
then
	mv /etc/php/php-fpm.d/www.conf /etc/php/php-fpm.d/www.conf.original ;
fi
if [ -f /etc/php/php-fpm.d/www-root.conf ]
then
	mv /etc/php/php-fpm.d/www-root.conf /etc/php/php-fpm.d/www-root.conf.original ;
fi
echo ";--------------------------------------;" > /etc/php/php-fpm.d/www-root.conf
echo "; Installed by r_nginx.sh v$r_nginx_version" >> /etc/php/php-fpm.d/www-root.conf
echo ";--------------------------------------;" >> /etc/php/php-fpm.d/www-root.conf
echo "" >> /etc/php/php-fpm.d/www-root.conf
cat r_nginx/www-root.conf >> /etc/php/php-fpm.d/www-root.conf
chmod go-wx /etc/php/php-fpm.d/www-root.conf
chmod go+r /etc/php/php-fpm.d/www-root.conf

#------------------------------ nftables ----------------------------#
echo "" >> /etc/nftables.conf
echo "" >> /etc/nftables.conf
echo "#--------------------------------------#" >> /etc/nftables.conf
echo "# Added by r_nginx.sh v$r_nginx_version" >> /etc/nftables.conf
echo "#--------------------------------------#" >> /etc/nftables.conf
echo "" >> /etc/nftables.conf
echo "# allow http and https incoming" >> /etc/nftables.conf
echo "add rule ip filter input tcp dport http accept" >> /etc/nftables.conf
echo "#IPv6: add rule ip6 filter input tcp dport http accept" >> /etc/nftables.conf
echo "add rule ip filter input tcp dport https accept" >> /etc/nftables.conf
echo "#IPv6: add rule ip6 filter input tcp dport https accept" >> /etc/nftables.conf
systemctl restart nftables
#--------------------------------------------------------------------#


#--------------------------------------------------------------------#
# Enable and start
#--------------------------------------------------------------------#
echo -e "\e[32mEnabling and starting web server services ...\e[0m"
systemctl enable nginx
systemctl start nginx
systemctl status nginx
systemctl enable php-fpm
systemctl start php-fpm
systemctl status php-fpm
#--------------------------------------------------------------------#
