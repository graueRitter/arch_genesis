# arch_genesis

This project contains a series of scripts to (mostly) automate the installation of Arch Linux hosts of various roles.

Project architecture is a 'building block' architecture, with base install scripts, and role scripts to install particular roles or applications after a base install script has been executed.

Script naming convention:

Operating system install script: <v|p>\_\<svr|wks>\_\<description>.sh

Role install script: <r_<role_name>.sh

Where:
* 'v':			indicates for virtual guest base install (tested on qemu version 2.12.1-1).
* 'p': 			indicates 'bare metal' base install.
* 'svr':			indicates this is a server install (sshd enabled).
* 'wks':			indicates this is a workstation install (no sshd enabled).
* 'r': 			indicates role install script, e.g. nginx, apache, Horde, PostgreSQL, MariaDB, etc. roles.
* 'description':	indicates description of base install.
* 'role_name':	indicates name of role to install.

## Prerequisites
* Physical machine or virtual machine run by qemu/KVM optionally managed by libvirt.
* Arch Linux install media (CD for physical machine, ISO or CD for virtual machine).
* Access to scripts (either on ISO, CD, network share, via scp, or some other method).
* bash 4.4 shell (may work on other versions or shells).

## Usage
Scripts must be run as root, requires the 'common' subfolder and subfolder whose name matches script name.

Initial clean install:
1. Boot into Arch Linux install media.
2. Copy desired script(s) and dependency folders into /tmp directory (or any other directory with write permissions).
3. Edit common/mirrorlist and add or uncomment desired mirrors.
4. Change into directory scripts copied to.
5. Execute base install script.
6. Reboot into newly installed operating system and perform post boot tasks (e.g. setting ntp settings as this cannot be performed within chroot).

Role install:
1. Log in to host.
2. Copy desired script(s) into /tmp directory (or any other directory with write permissions).
3. Change into directory scripts copied to.
4. Execute desired role install script.
5. Perform pre reboot configuration.
6. Reboot.
7. Perform post reboot configuration.
8. Verify working.

## Issues
* If installing on disk that already has partitions and file system and new partition table is identical to original then files in file system are not deleted and duplicate entries will be created in config files: /etc/fstab, /etc/ssh/sshd_config, and sudoers file which will lead to errors. This could be viewed either as a use case the script does not cater for, or a safety feature ;-).
* Cannot enable NTP within chroot script (timedatectl set-ntp true). Until a workaround is developed, this (if needed) must be done after booting into installed operating system.

## Contributors

https://wiki.archlinux.org/index.php/Installation_guide

## Contents

### server.template
Template server configuration file. copy and edit for specific server properties.

### common/mirrorlist
List of mirrors to download packages. Must be edited before use to enable mirror URLs.

### common/list
Wrapper around the 'ls' command which displays details as well as date and time with timezone offset.

### v_svr_base.sh
Performs the initial base install. Includes ssh daemon with login as root denied. Networking is configured using systemd-networkd service and related configuration files.

### v_svr_base_chroot.sh
Performs post base install chroot configurations. As NTP cannot be enabled within chroot this needs to be performed after this script has finished and rebooted.

### v_svr_base/nftables.config
Initial firewall configuration file (nftables). Blocks IPv6, allows IPv4 ICMP and ssh.
