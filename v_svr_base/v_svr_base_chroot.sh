#--------------------------------------------------------------------#
# Defaults
# - <ALL_CAPS> replaced by v_svr_base.sh
#--------------------------------------------------------------------#
v_svr_base_chroot_version="0.4.0"
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
echo -e "\e[32mSeting timezone and clock...\e[0m"
ln -s -f /usr/share/zoneinfo/$region/$zone /etc/localtime
hwclock --systohc

# set locale to en_AU.UTF-8
echo -e "\e[32mSeting locale...\e[0m"
sed -e s/"#$locale"/"$locale"/g /etc/locale.gen > /etc/locale.gen.tmp && mv --force /etc/locale.gen.tmp /etc/locale.gen
# generate locales
locale-gen
# update /etc/locale.conf
echo LANG=$locale > /etc/locale.conf
cat /etc/locale.conf

# Add hostname
echo -e "\e[32mSeting host name...\e[0m"
echo "#--------------------------------------#" >> /etc/hostname
echo "# Added by v_svr_bash_chroot.sh v$v_svr_base_chroot_version" >> /etc/hostname
echo "#--------------------------------------#" >> /etc/hostname
echo $name > /etc/hostname
echo "" >> /etc/hosts
echo "" >> /etc/hosts
echo "#--------------------------------------#" >> /etc/hosts
echo "# Added by v_svr_bash_chroot.sh v$v_svr_base_chroot_version" >> /etc/hosts
echo "#--------------------------------------#" >> /etc/hosts
echo "127.0.0.1 $name.$fqdn $name" >> /etc/hosts

# configure RAM disk image
echo -e "\e[32mConfigure RAM disk image...\e[0m"
mkinitcpio -p linux

# enable 1 GiB swap file
echo -e "\e[32mCreating 1 GiB swap file...\e[0m"
dd if=/dev/zero of=/swapfile bs=1M count=1024
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo ""
echo ""
echo "#--------------------------------------#" >> /etc/fstab
echo "# Added by v_svr_bash_chroot.sh v$v_svr_base_chroot_version" >> /etc/fstab
echo "#--------------------------------------#" >> /etc/fstab
echo '/swapfile none swap defaults 0 0' >> /etc/fstab

# enable network
echo -e "\e[32mEnabling network...\e[0m"
systemctl enable systemd-networkd.service

# enable nftables firewall
echo -e "\e[32mEnabling nftables firewall...\e[0m"
systemctl enable nftables.service

#enable ssh daemon
echo -e "\e[32mEnabling ssh access...\e[0m"
systemctl enable sshd.service

# enable NTP datetime synchronisation
echo -e "\e[32mEnabling NTP datetime synchronisation...\e[0m"
systemctl enable systemd-timesyncd.service

# install boot loaders
echo -e "\e[32mInstalling boot loader...\e[0m"
grub-install --target=i386-pc --boot-directory /boot $bootloader_device
# replace GRUB_CMDLINE_LINUX and GRUB_CMDLINE_LINUX_DEFAULT options
sed -e s/'GRUB_CMDLINE_LINUX'/'#GRUB_CMDLINE_LINUX'/g /etc/default/grub > /etc/default/grub.tmp && mv --force /etc/default/grub.tmp /etc/default/grub
sed -e s/'GRUB_CMDLINE_LINUX_DEFAULT'/'#GRUB_CMDLINE_LINUX_DEFAULT'/g /etc/default/grub > /etc/default/grub.tmp && mv --force /etc/default/grub.tmp /etc/default/grub
# enable recovery mode (below)
sed -e s/'GRUB_DISABLE_RECOVERY'/'#GRUB_CMDLINE_LINUX_DEFAULT'/g /etc/default/grub > /etc/default/grub.tmp && mv --force /etc/default/grub.tmp /etc/default/grub
echo "" >> /etc/default/grub
echo "#--------------------------------------#" >> /etc/default/grub
echo "# Added by v_svr_bash_chroot.sh v$v_svr_base_chroot_version" >> /etc/default/grub
echo "#--------------------------------------#" >> /etc/default/grub
# configure serial console
echo 'GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8"' >> /etc/default/grub
echo 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"' >> /etc/default/grub
echo 'GRUB_TERMINAL="console serial"' >> /etc/default/grub
echo 'GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"' >> /etc/default/grub
# enable recovery mode menu item(s)
echo 'GRUB_DISABLE_RECOVERY=false' >> /etc/default/grub
# create grub2 configuration
grub-mkconfig -o /boot/grub/grub.cfg

# create admin user
tmpAdminUser="GR_ADMIN_ACCOUNT"
adminUser=${tmpAdminUser,,}
useradd -g users -m -N $adminUser
echo -e "Enter password for \e[32m$adminUser\e[0m:"
passwd $adminUser

# Last: change root password
echo -e "Enter password for \e[1;31mroot\e[0m:"
passwd

#--------------------------------------------------------------------#
# Cleanup
#--------------------------------------------------------------------#
rm /v_svr_base_chroot.sh
#--------------------------------------------------------------------#

read -p "Press [Enter] key to finish script and then reboot into guest operating system."
echo ""
#--------------------------------------------------------------------#


