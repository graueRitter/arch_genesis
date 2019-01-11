#--------------------------------------------------------------------#
# Defaults
# - <ALL_CAPS> replaced by v_svr_base.sh
#--------------------------------------------------------------------#
v_svr_base_chroot_version="0.0.1"
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
systemctl enable systemd-networkd

# enable nftables firewall
echo -e "\e[32mEnabling nftables firewall...\e[0m"
systemctl enable nftables

#enable ssh daemon
echo -e "\e[32mEnabling ssh access...\e[0m"
systemctl enable sshd

# enable NTP datetime synchronisation
#read -p "About to enable NTP time synchronisation"
# need networking up first...: timedatectl set-ntp true

# create user(s)
tmpAdminUser="GR_ADMIN_ACCOUNT"
adminUser=${tmpAdminUser,,}
useradd -g users -m -N $adminUser
echo "Enter password for $adminUser"
passwd $adminUser

# install boot loaders
echo -e "\e[32mInstalling boot loader...\e[0m"
grub-install --target=i386-pc --boot-directory /boot $bootloader_device
grub-mkconfig -o /boot/grub/grub.cfg

# Last: change root password
echo "Change root password:"
passwd

#--------------------------------------------------------------------#
# Cleanup
#--------------------------------------------------------------------#
rm /v_svr_base_chroot.sh
#--------------------------------------------------------------------#

read -p "Press any key to finish script and then unmount -R /mnt, and systemctl reboot. Then execute #timedatectl set-ntp true"
echo ""
#--------------------------------------------------------------------#


