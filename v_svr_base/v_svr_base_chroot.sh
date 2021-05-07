#!/bin/bash
source ./functions

#--------------------------------------------------------------------#
# Defaults
# - <ALL_CAPS> replaced by v_svr_base.sh
#--------------------------------------------------------------------#
v_svr_base_chroot_version="1.0.0"
name=GR_NAME
fqdn=GR_FQDN
bootloader_device=GR_BOOTLOADERDEVICE
locale=GR_LOCALE
region=GR_REGION
zone=GR_ZONE
#--------------------------------------------------------------------#


#--------------------------------------------------------------------#
# Configure
#--------------------------------------------------------------------#

# locale
echo -e "\e[32mSetting timezone and clock\e[0m"
current_task='Setting timezone'
ln -s -f /usr/share/zoneinfo/$region/$zone /etc/localtime
exit_on_error $? "$current_task"
hwclock --systohc
exit_on_error $? "$current_task"
echo ''

# set locale to en_AU.UTF-8
echo -e "\e[32mSeting locale\e[0m"
current_task='Setting locale'
sed -e s/"#$locale"/"$locale"/g /etc/locale.gen > /etc/locale.gen.tmp && mv --force /etc/locale.gen.tmp /etc/locale.gen
exit_on_error $? "$current_task"
# generate locales
locale-gen
exit_on_error $? "$current_task"
# update /etc/locale.conf
echo LANG=$locale > /etc/locale.conf
exit_on_error $? "$current_task"
cat /etc/locale.conf
echo ''

# Add hostname
echo -e "\e[32mSeting host name\e[0m"
current_task='Setting host name'
echo "#--------------------------------------#" >> /etc/hostname
exit_on_error $? "$current_task"
echo "# Added by v_svr_bash_chroot.sh v$v_svr_base_chroot_version" >> /etc/hostname
exit_on_error $? "$current_task"
echo "#--------------------------------------#" >> /etc/hostname
exit_on_error $? "$current_task"
echo $name > /etc/hostname
exit_on_error $? "$current_task"
echo "" >> /etc/hosts
exit_on_error $? "$current_task"
echo "" >> /etc/hosts
exit_on_error $? "$current_task"
echo "#--------------------------------------#" >> /etc/hosts
exit_on_error $? "$current_task"
echo "# Added by v_svr_bash_chroot.sh v$v_svr_base_chroot_version" >> /etc/hosts
exit_on_error $? "$current_task"
echo "#--------------------------------------#" >> /etc/hosts
exit_on_error $? "$current_task"
echo "127.0.1.1 $name.$fqdn $name" >> /etc/hosts
exit_on_error $? "$current_task"
echo ''

# configure RAM disk image
# performed as part of pacstrap in v_svr_base.sh
# only needed if RAM disk image configuration changes 
#  post pacstrap
# if this script makes changes to RAM disk image settings then 
#  reinstate below lines
#echo -e "\e[32mConfigure RAM disk image\e[0m"
#mkinitcpio -p linux
#echo ''

# enable 1 GiB swap file
echo -e "\e[32mCreating 1 GiB swap file\e[0m"
current_task='Adding swap file'
dd if=/dev/zero of=/swapfile bs=1M count=1024
exit_on_error $? "$current_task"
chmod 600 /swapfile
exit_on_error $? "$current_task"
mkswap /swapfile
exit_on_error $? "$current_task"
swapon /swapfile
exit_on_error $? "$current_task"
echo "" >> /etc/fstab
exit_on_error $? "$current_task"
echo "#--------------------------------------#" >> /etc/fstab
exit_on_error $? "$current_task"
echo "# Added by v_svr_bash_chroot.sh v$v_svr_base_chroot_version" >> /etc/fstab
exit_on_error $? "$current_task"
echo "#--------------------------------------#" >> /etc/fstab
exit_on_error $? "$current_task"
echo '/swapfile none swap defaults 0 0' >> /etc/fstab
exit_on_error $? "$current_task"
echo ''

# enable network
echo -e "\e[32mEnabling network\e[0m"
current_task='Enabling network'
systemctl enable systemd-networkd.service
exit_on_error $? "$current_task"
echo ''

# enable nftables firewall
echo -e "\e[32mEnabling nftables firewall\e[0m"
current_task='Enable nftables firewall'
systemctl enable nftables.service
exit_on_error $? "$current_task"
echo ''

#enable ssh daemon
echo -e "\e[32mEnabling ssh access\e[0m"
current_task='Enable ssh daemon service'
systemctl enable sshd.service
exit_on_error $? "$current_task"
echo ''

# enable NTP datetime synchronisation
echo -e "\e[32mEnabling NTP datetime synchronisation\e[0m"
current_task='Enablint time synchronisation (NTP)'
systemctl enable systemd-timesyncd.service
exit_on_error $? "$current_task"
echo ''

# enable qemu guest agent
echo -e "\e[32mEnabling qemu guest agent\e[0m"
current_task='Installing qemu guest agent'
systemctl enable qemu-guest-agent.service
exit_on_error $? "$current_task"
echo ''

# install boot loaders
echo -e "\e[32mInstalling and configuring grub2 boot loader\e[0m"
current_task='Installing and configuring grub2 boot loader'
grub-install --target=i386-pc --boot-directory /boot $bootloader_device
exit_on_error $? "$current_task"
# replace GRUB_CMDLINE_LINUX and GRUB_CMDLINE_LINUX_DEFAULT options
sed -e s/'GRUB_CMDLINE_LINUX'/'#GRUB_CMDLINE_LINUX'/g /etc/default/grub > /etc/default/grub.tmp && mv --force /etc/default/grub.tmp /etc/default/grub
exit_on_error $? "$current_task"
sed -e s/'GRUB_CMDLINE_LINUX_DEFAULT'/'#GRUB_CMDLINE_LINUX_DEFAULT'/g /etc/default/grub > /etc/default/grub.tmp && mv --force /etc/default/grub.tmp /etc/default/grub
exit_on_error $? "$current_task"
# enable recovery mode (below)
sed -e s/'GRUB_DISABLE_RECOVERY'/'#GRUB_CMDLINE_LINUX_DEFAULT'/g /etc/default/grub > /etc/default/grub.tmp && mv --force /etc/default/grub.tmp /etc/default/grub
exit_on_error $? "$current_task"
echo '' >> /etc/default/grub
exit_on_error $? "$current_task"
echo "#--------------------------------------#" >> /etc/default/grub
exit_on_error $? "$current_task"
echo "# Added by v_svr_bash_chroot.sh v$v_svr_base_chroot_version" >> /etc/default/grub
exit_on_error $? "$current_task"
echo "#--------------------------------------#" >> /etc/default/grub
exit_on_error $? "$current_task"
# enable recovery mode menu item(s)
echo 'GRUB_DISABLE_RECOVERY=false' >> /etc/default/grub
exit_on_error $? "$current_task"
echo '' >> /etc/default/grub
exit_on_error $? "$current_task"
# configure serial console
echo '' >> /etc/default/grub
exit_on_error $? "$current_task"
echo 'GRUB_TERMINAL="console serial"' >> /etc/default/grub
exit_on_error $? "$current_task"
echo 'GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"' >> /etc/default/grub
exit_on_error $? "$current_task"
echo '' >> /etc/default/grub
exit_on_error $? "$current_task"
echo 'GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8"' >> /etc/default/grub
exit_on_error $? "$current_task"
echo 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"' >> /etc/default/grub
exit_on_error $? "$current_task"
echo '' >> /etc/default/grub
exit_on_error $? "$current_task"
# create grub2 configuration
grub-mkconfig -o /boot/grub/grub.cfg
exit_on_error $? "$current_task"
echo ''

# create admin user
current_task='Create administration user'
tmpAdminUser="GR_ADMIN_ACCOUNT"
adminUser=${tmpAdminUser,,}
useradd -g users -m -N $adminUser
exit_on_error $? "$current_task"
echo -e "Enter password for \e[32m$adminUser\e[0m:"
passwd $adminUser
exit_on_error $? "$current_task"
echo ''

# change root password
echo -e "Enter password for \e[1;31mroot\e[0m:"
passwd
exit_on_error $? "$current_task"
echo ''

#--------------------------------------------------------------------#
# Cleanup
#--------------------------------------------------------------------#
current_task='Clean up'
rm /v_svr_base_chroot.sh
rm /functions
exit_on_error $? "$current_task"
#--------------------------------------------------------------------#

read -p "Press [Enter] key to finish script and then reboot into guest operating system."
echo ''
#--------------------------------------------------------------------#
