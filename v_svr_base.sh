#!/bin/bash
#--------------------------------------------------------------------#
# Options file variables
#--------------------------------------------------------------------#
# name = host name
# fqdn = fully qualified domain name
# locale = language locale, e.g. en_AU.UTF-8
# region = region host is in (for setting timezone)
# zone = zone host is in (for setting timezone)
# admin = user name of account that has global sudo access
# search_domain = domain to be appended if only host name given
# ip_address = IPv4 address of host including subnet mask bits
# ns_ip_address = IPv4 address of name server
# gateway = IPv4 address of gateway
#--------------------------------------------------------------------#

#--------------------------------------------------------------------#
# Defaults
#--------------------------------------------------------------------#
v_svr_base_version="0.0.0"
#--------------------------------------------------------------------#


#--------------------------------------------------------------------#
# Functions
#--------------------------------------------------------------------#
function print_usage
{
	echo '/* -- Help: --*/'
	# does this script really require guest options?
	#  - main requirement is 1M partition is for SeaBIOS to boot GPT disk
	echo 'Requires guest created with qemu settings (others may work):'
	echo "- machine='pc' # actually alias for 'pc-440fx-2.1'"
	echo "- virt_type='kvm'"
	echo "- virtioSupport='true'"
	echo "- architecture='x86_64'"
	echo "- cpu='host'"
	echo ''
	echo 'Syntax: v_svr_base.sh <configuration file>' >&2 ;
	echo "Where configuration file defines the following variables:"
	echo "  Host:"
	echo "    \$name => host name"
	echo "    \$fqdn => domain <d1>...<dn>"
	echo "    \$locale => e.g. en_AU.UTF-8"
	echo "    \$region => e.g. Etc"
	echo "    \$zone => e.g. UTC"
	echo "    \$admin => administration user with global sudo access"
	echo "  Networking:"
	echo "    \$search_domain => default domain to be appended if only hostname given"
	echo "    \$ip_address => IPv4 address: <octet 1>.<octet 2>.<octet 3>.<octet 4>\/<subnetmask>"
	echo "    \$ns_ip_address => name server IPv4 address: <octet 1>.<octet 2>.<octet 3>.<octet 4>"
	echo "    \$gateway => gateway IPv4 address: <octet 1>.<octet 2>.<octet 3>.<octet 4>"
	echo '/* -- End Help -- */'
}

function print_option_file_variables
{
	echo '/* -- Validating options file ... --*/'
	echo "  Host:"
	echo "    Host name: $name"
	echo "    Fully qualified domain name: $fqdn"
	echo "    Locale: $locale"
	echo "    Region: $region"
	echo "    Time zone: $zone"
	echo "    Administration account: $admin"
	echo "  Networking:"
	echo "    Host IPv4 address: $ip_address"
	echo "    Search domain: $search_domain"
	echo "    Name server IPv4 address: $ns_ip_address"
	echo "    Gateway address: $gateway"
}

function print_partition_prerequisites
{
	echo '/* -- Partition prerequisites: --*/'
	echo 'Current block devices:'
	lsblk -o NAME
	echo
	echo '/dev/vda must exist.'
	echo 'Are you sure this is a qemu/KVM virtual machine?'
	echo '/* -- End Partition prerequisites -- */'
}
#--------------------------------------------------------------------#


#--------------------------------------------------------------------#
# Initialise variables
#--------------------------------------------------------------------#

# for virtual machines ass-u-me:
bootloader_device=/dev/vda
root_partition=/dev/vda2

# Note that we use `"$@"' to let each command-line parameter expand to a
# separate word. The quotes around `$@' are essential!
# We need TEMP as the `eval set --' would nuke the return value of getopt.
# with scp: TEMP=`getopt --options hn:f:l:r:z:s:u: --long help,name:,fqdn:,locale:,region:,zone:,scproot:,user: -n 'v_svr_base.sh' -- "$@"`
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
echo -e "\e[0;34mStarting v_svr_base v$v_svr_base_version\e[0m"
echo ''
echo -e "\e[0;32mPerforming preflight checks...\e[0m"
# check /dev/vda exists
if [[ ! $(lsblk -o NAME) =~ "vda" ]]
then
	print_partition_prerequisites ;
	exit 1 ;
fi
# ask human to verify variables
print_option_file_variables
echo ''
lsblk
echo -e "\e[0;31mAbout to totally delete $bootloader_device !!! ...\e[0m"
echo -e "\e[0;31mCheck VERY carefully partition devices! ! ! Ctrl-c to abort, other key to proceed ...\e[0m"
read
echo ''
#--------------------------------------------------------------------#


#--------------------------------------------------------------------#
# Partition disk
#--------------------------------------------------------------------#
echo -e "\e[32mPatitioning disk...\e[0m"
# delete existing data
sgdisk -og $bootloader_device
STARTSECTOR=$(sgdisk -F $bootloader_device)
sgdisk -n 1:$STARTSECTOR:+1M -c 1:"BIOS Boot Partition" -t 1:ef02 $bootloader_device
STARTSECTOR=$(sgdisk -F $bootloader_device)
ENDSECTOR=$(sgdisk -E $bootloader_device)
sgdisk -n 2:$STARTSECTOR:$ENDSECTOR -c 2:"root" -t 2:8300 $bootloader_device
sgdisk -p $bootloader_device
echo ""
#--------------------------------------------------------------------#


#--------------------------------------------------------------------#
# Format disk
#--------------------------------------------------------------------#
echo -e "\e[32mFormating root partition...\e[0m"
mkfs.ext4 -E lazy_itable_init=0,lazy_journal_init=0 -L root $root_partition
echo ""
#--------------------------------------------------------------------#


#--------------------------------------------------------------------#
# Install
#--------------------------------------------------------------------#
# mount partitions
echo -e "\e[32mMounting partitions...\e[0m"
mount $root_partition /mnt
mkdir /mnt/boot

# install minimum packages
echo -e "\e[32mInstalling base operating system...\e[0m"
pacstrap /mnt base sudo grub intel-ucode nftables openssh

# generate boot loaded file systems
echo -e "\e[32mGenerating /etc/fstab...\e[0m"
genfstab -U /mnt >> /mnt/etc/fstab

echo -e "\e[32mCopying configuration files and base scripts...\e[0m"
# add nftables base configuration
cp -p ./v_svr_base/nftables.conf /mnt/etc
chmod go-rwx /mnt/etc/nftables.conf
# add source script for default configuration
#  single sed line below adds two newlines which is what is wanted,
#  but begs question: how to insert only single line with sed?
sed -i '2i#--------------------------------------#' /mnt/etc/nftables.conf
sed -i "2i# Installed by v_svr_bash.sh v$v_svr_base_version" /mnt/etc/nftables.conf
sed -i '2i#--------------------------------------#' /mnt/etc/nftables.conf
sed -i '2i\\n' /mnt/etc/nftables.conf

# copy ls wrapper 'list'
cp -p ./common/list /mnt/usr/local/bin
chmod go-w /mnt/usr/local/bin/list
chmod go+rx /mnt/usr/local/bin/list

# copy mirrorlist
cp -p ./common/mirrorlist /mnt/etc/pacman.d
#--------------------------------------------------------------------#


#--------------------------------------------------------------------#
# Configure
#--------------------------------------------------------------------#

# configure ssh: no root login
echo -e "\e[32mSecuring sshd...\e[0m"
echo "" >> /mnt/etc/ssh/sshd_config
echo "" >> /mnt/etc/ssh/sshd_config
echo "#--------------------------------------#" >> /mnt/etc/ssh/sshd_config
echo "# Added by v_svr_bash.sh v$v_svr_base_version" >> /mnt/etc/ssh/sshd_config
echo "#--------------------------------------#" >> /mnt/etc/ssh/sshd_config
echo "PermitRootLogin no" >> /mnt/etc/ssh/sshd_config

# configure sudo
echo -e "\e[32mConfiguring sudo...\e[0m"
tmpAdminUser=$admin
adminUser=${tmpAdminUser,,}
echo "" >> /mnt/etc/sudoers
echo "" >> /mnt/etc/sudoers
echo "#--------------------------------------#" >> /mnt/etc/sudoers
echo "# Added by v_svr_bash.sh v$v_svr_base_version" >> /mnt/etc/sudoers
echo "#--------------------------------------#" >> /mnt/etc/sudoers
echo "User_Alias      ADMINS_SUDO = $adminUser" >> /mnt/etc/sudoers
echo "ADMINS_SUDO $name=(ALL) ALL" >> /mnt/etc/sudoers

# configure networking
echo -e "\e[32mConfiguring network...\e[0m"
#  name resolution
echo "" >> /mnt/etc/resolve.conf
echo "" >> /mnt/etc/resolv.conf
echo "#--------------------------------------#" >> /mnt/etc/resolv.conf
echo "# Added by v_svr_bash.sh v$v_svr_base_version" >> /mnt/etc/resolv.conf
echo "#--------------------------------------#" >> /mnt/etc/resolv.conf
echo "search $search_domain" >> /mnt/etc/resolv.conf
echo "nameserver $ns_ip_address" >> /mnt/etc/resolv.conf
#  network interface
echo "#--------------------------------------#" >> /mnt/etc/systemd/network/$fqdn.network
echo "# Created by v_svr_bash.sh v$v_svr_base_version" >> /mnt/etc/systemd/network/$fqdn.network
echo "#--------------------------------------#" >> /mnt/etc/systemd/network/$fqdn.network
echo "[Match]" >> /mnt/etc/systemd/network/$fqdn.network
echo "Name=ens3" >> /mnt/etc/systemd/network/$fqdn.network
echo "" >> /mnt/etc/systemd/network/$fqdn.network
echo "[Link]" >> /mnt/etc/systemd/network/$fqdn.network
echo "" >> /mnt/etc/systemd/network/$fqdn.network
echo "[Address]" >> /mnt/etc/systemd/network/$fqdn.network
echo "Address=$ip_address" >> /mnt/etc/systemd/network/$fqdn.network
echo "" >> /mnt/etc/systemd/network/$fqdn.network
echo "[Route]" >> /mnt/etc/systemd/network/$fqdn.network
echo "Gateway=$gateway" >> /mnt/etc/systemd/network/$fqdn.network
#--------------------------------------------------------------------#


#--------------------------------------------------------------------#
# Configure chroot script
#--------------------------------------------------------------------#
# copy inside arch-chroot script
echo -e "\e[32mConfiguring chroot script...\e[0m"
cp -p ./v_svr_base_chroot.sh /mnt
# substituting in variables from parent (v_svr_base.sh)
sed -e s/"GR_NAME"/"$name"/g /mnt/v_svr_base_chroot.sh > /mnt/inside_chroot.tmp && mv --force /mnt/inside_chroot.tmp /mnt/v_svr_base_chroot.sh
sed -e s/"GR_FQDN"/"$fqdn"/g /mnt/v_svr_base_chroot.sh > /mnt/inside_chroot.tmp && mv --force /mnt/inside_chroot.tmp /mnt/v_svr_base_chroot.sh
sed -e s@"GR_BOOTLOADERDEVICE"@"$bootloader_device"@g /mnt/v_svr_base_chroot.sh > /mnt/inside_chroot.tmp && mv --force /mnt/inside_chroot.tmp /mnt/v_svr_base_chroot.sh
sed -e s@"GR_LOCALE"@"$locale"@g /mnt/v_svr_base_chroot.sh > /mnt/inside_chroot.tmp && mv --force /mnt/inside_chroot.tmp /mnt/v_svr_base_chroot.sh
sed -e s@"GR_REGION"@"$region"@g /mnt/v_svr_base_chroot.sh > /mnt/inside_chroot.tmp && mv --force /mnt/inside_chroot.tmp /mnt/v_svr_base_chroot.sh
sed -e s@"GR_ZONE"@"$zone"@g /mnt/v_svr_base_chroot.sh > /mnt/inside_chroot.tmp && mv --force /mnt/inside_chroot.tmp /mnt/v_svr_base_chroot.sh

chmod u+x /mnt/v_svr_base_chroot.sh

# and run chroot tasks
arch-chroot /mnt /v_svr_base_chroot.sh
#--------------------------------------------------------------------#