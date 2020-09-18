#!/bin/bash
source ./common/functions

#--------------------------------------------------------------------#
# Parameters
#--------------------------------------------------------------------#
# databaseInstance = database instance
#
#--------------------------------------------------------------------#

#--------------------------------------------------------------------#
# Defaults
#--------------------------------------------------------------------#
r_mariadb_version="0.0.1"
installString=''
#--------------------------------------------------------------------#

#--------------------------------------------------------------------#
# Functions
#--------------------------------------------------------------------#
{
function print_usage
{
	echo '/* -- Help: --*/'
	echo 'Installs MariaDB service with root data file location /srv/databases/<database instance directory>'
	echo ''
	echo 'Syntax: r_mariadb.sh <configuration file>' >&2 ;
	echo "Where configuration file defines the following variable:"
	echo "  \$databaseInstance => database instance: data in /srv/databases/\$databaseInstance"
	echo '/* -- End Help -- */'
}

function print_option_file_variables
{
	echo '--> Validate options file:'
	echo "      Data directory: /srv/databases/$databaseInstance"
}

function fix_Btrfs
{
	echo 'ToDo: write fix/warning code'
}

function fix_ZFS
{
	echo 'ToDo: write fix/warning code'
}

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

echo -e "\e[0;34mStarting r_mariadb.sh v$r_mariadb_version\e[0m"
echo ''

#--------------------------------------------------------------------#
# Load options
#--------------------------------------------------------------------#
. $1
#--------------------------------------------------------------------#

#--------------------------------------------------------------------#
# Pre flight checks
#--------------------------------------------------------------------#
{
# ensure running as root - exit if not
# check mount options: noexec, nosuid, etc.
# check if MariaDB already installed, skipping install step if installed
# check if database instance already created

# check if root privileges
if [[ $(id -u) -ne 0 ]] ; then echo -e "\e[0;31mPlease run as root\e[0m" ; exit 1 ; fi

# check mount options - should contain nosuid and noexec
srvMount=`cat /etc/fstab | egrep -v "^[[:blank:]]*(#|$)" | grep 'srv'`
if [[ $srvMount != *"nosuid"* || $srvMount != *"noexec"* ]]  ;
then
	echo -e "\e[0;33m--> Warning: html root not mounted without noexec and/or nosuid options\e[0m" ;
	# should not show as may be part of "/" filesystem: echo "  /etc/fstab:"
	# should not show as may be part of "/" filesystem: cat /etc/fstab | grep '/srv' ;
	echo ''
else
	echo -e "\e[0;32m--> Checked noexec and nosuid mount option: Ok\e[0m" ;
	echo ''
fi

# check for MariaDB
pacman -Q mariadb &>/dev/null
if [ $? -eq 0 ]
then
	echo '--> MariaDB is installed, skipping install...' ;
else
	installString="$installString mariadb"
fi

# check if mariadb instance already installed
if [ -d "/srv/databases/$databaseInstance" ] ;
then
	echo -e "\e[0;33m--> Error: database instance $databaseInstance already created\e[0m" ;
	echo -e "      ->  change databaseInstance value in $1 and re run" ;
	exit 2 ;
fi

# ask human to verify variables
print_option_file_variables
echo ''
echo -e "\e[0;31mAbout to install and configure MariaDB database server...\e[0m"
echo -e "\e[0;31m  -> creating database in /srv/databases/$databaseInstance\e[0m"
echo -e "\e[0;31mCtrl-c to abort, Press any key to proceed...\e[0m"
read -s -n 1 -r
echo ''
}
#--------------------------------------------------------------------#

#--------------------------------------------------------------------#
# Install
#--------------------------------------------------------------------#
# potential issues here:
#  https://unix.stackexchange.com/questions/52277/pacman-option-to-assume-yes-to-every-question
#  - will break if pacman asks for a selection. Perform manual '-syu' first then just '-S'?
if [[ $installString != '' ]] ;
then
	echo -e "\e[32m--> Installing: $installString...\e[0m"
	current_task="Installing packages"
	pacman --noconfirm -S $installString
	# or pacman -Syu --noconfirm $installString ?
	exit_on_error $? "$current_task"
fi

#--------------------------------------------------------------------#


#--------------------------------------------------------------------#
# Configure
#--------------------------------------------------------------------#
echo -e "\e[32m--> Configuring MariaDB database in /srv/databases/$databaseInstance...\e[0m"

###------------------------------ nftables ----------------------------#
##echo "" >> /etc/nftables.conf
##echo "" >> /etc/nftables.conf
##echo "#--------------------------------------#" >> /etc/nftables.conf
##echo "# Added by r_mariadb.sh v$r_mariadb_version" >> /etc/nftables.conf
##echo "#--------------------------------------#" >> /etc/nftables.conf
##echo "" >> /etc/nftables.conf
##echo "# allow standard mariadb port" >> /etc/nftables.conf
##echo "add rule ip filter input tcp dport mysql accept" >> /etc/nftables.conf
##echo "#IPv6: add rule ip6 filter input tcp dport mysql accept" >> /etc/nftables.conf
##systemctl restart nftables
###--------------------------------------------------------------------#

#------------------------------ mariadb -----------------------------#

# create data directory
current_task='Create MariaDB data directory'
if [ ! -d "/srv/databases/$databaseInstance" ]; 
then
	mkdir -p "/srv/databases/$databaseInstance"
	exit_on_error $? "$current_task"
fi

### check if filesystem fixes needed (cannot perform in preflight as directory must exist first)
##dataFilesystem=`df -PT $databaseInstance | awk 'NR==2 {print $2}'`
##dataFilesystemLC=${dataFilesystem,,}
### if Btrfs then apply fix
##if [[ $dataDir == 'Btrfs' ]] ;
##then
##	fix_Btrfs
##fi
### if ZFS then apply fix
##if [[ $dataDir == 'ZFS' ]] ;
##then
##	fix_ZFS
##fi

# configure MariaDB instance
current_task='Configure MariaDB database instance'
mysql_install_db --user=mysql --basedir=/usr --datadir="/srv/databases/$databaseInstance"
exit_on_error $? "$current_task"
# ensure correct ownership - may not be necessary?
chown --recursive mysql:mysql "/srv/databases/$databaseInstance"
exit_on_error $? !"$current_task"
chmod --recursive go-rwx "/srv/databases/$databaseInstance"
exit_on_error $? "$current_task"
# point to data directory in my.cnf
if [ -f /etc/mysql/my.cnf ]
then
	cp -a /etc/mysql/my.cnf /etc/mysql/my.cnf.original ;
	exit_on_error $? "$current_task"
fi
echo '' >> /etc/mysql/my.cnf
exit_on_error $? "$current_task"
echo "#--------------------------------------#" >> /etc/mysql/my.cnf
exit_on_error $? "$current_task"
echo "# Installed by r_mariadb.sh v$r_mariadb_version" >> /etc/mysql/my.cnf
exit_on_error $? "$current_task"
echo "#--------------------------------------#" >> /etc/mysql/my.cnf
exit_on_error $? "$current_task"
echo '' >> /etc/mysql/my.cnf
exit_on_error $? "$current_task"
echo '[client]' >> /etc/mysql/my.cnf
exit_on_error $? "$current_task"
echo "socket = '/run/mysqld/mysqld-$databaseInstance.sock'" >> /etc/mysql/my.cnf
exit_on_error $? "$current_task"
echo 'default-character-set = utf8mb4' >> /etc/mysql/my.cnf
exit_on_error $? "$current_task"
echo '' >> /etc/mysql/my.cnf
exit_on_error $? "$current_task"
echo '[mysqld]' >> /etc/mysql/my.cnf
exit_on_error $? "$current_task"
echo "datadir = '/srv/databases/$databaseInstance'" >> /etc/mysql/my.cnf
exit_on_error $? "$current_task"
echo "socket = '/run/mysqld/mysqld-$databaseInstance.sock'" >> /etc/mysql/my.cnf
exit_on_error $? "$current_task"
echo 'collation_server = utf8mb4_unicode_ci' >> /etc/mysql/my.cnf
exit_on_error $? "$current_task"
echo 'character_set_server = utf8mb4' >> /etc/mysql/my.cnf
exit_on_error $? "$current_task"
echo 'innodb_file_per_table = 1' >> /etc/mysql/my.cnf
exit_on_error $? "$current_task"
echo '' >> /etc/mysql/my.cnf
exit_on_error $? "$current_task"
echo '[mysql]' >> /etc/mysql/my.cnf
exit_on_error $? "$current_task"
echo 'default-character-set = utf8mb4' >> /etc/mysql/my.cnf
exit_on_error $? "$current_task"

#--------------------------------------------------------------------#
# Enable, start, and secure
#--------------------------------------------------------------------#
echo -e "\e[32m--> Enabling and starting database service...\e[0m"
current_task='Enabling and starting MariaDB database service'
systemctl enable mariadb
exit_on_error $? "$current_task"
systemctl start mariadb
exit_on_error $? "$current_task"
# secure MariaDB instance
#  - for some reason not yet resolved need to restart, or 'root'
#    cannot login from 'localhost'.
#systemctl restart mariadb
echo -e "\e[32m--> Securing MariaDB database...\e[0m"
current_task='Securing database'
# mysql_secure_installation ignores my.cnf and uses socket /run/mysqld/mysqld.sock
ln -s /run/mysqld/mysqld-$databaseInstance.sock /run/mysqld/mysqld.sock
exit_on_error $? "$current_task"
mysql_secure_installation
exit_on_error $? "$current_task"
rm /run/mysqld/mysqld.sock
exit_on_error $? "$current_task"
systemctl restart mariadb
exit_on_error $? "$current_task"

#--------------------------------------------------------------------#

echo ''
echo -e "\e[0;32mNow log on as mysql 'root' user ($ mysql -u root -p) and create database(s)/user(s) etc. as needed.\e[0m"
echo -e "\e[0;32mPress any key to exit script.\e[0m"
read -s -n 1 -r
echo ''
