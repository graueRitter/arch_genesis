0 arch_genesis
==============

0.0 Purpose
-----------

This project contains a series of scripts to (mostly) automate the installation of new Arch Linux hosts of various roles.

Project architecture is a 'building block' architecture, with base install scripts, and role scripts to install particular roles or applications after a base install script has been executed.

Script naming convention:

* Operating system install script: `<v|p>_<svr|wks>_<description>.sh`

* Role install script: `r_<role_name>.sh`

Where:  
`v`: indicates virtual guest base install (tested on qemu version 5.2.0-4).      
`p`: indicates 'bare metal' base install.  
`svr`: indicates this is a server install (sshd enabled).  
`wks`: indicates this is a workstation install (no sshd enabled).  
`r`: indicates role install script, e.g. nginx, apache, Horde, PostgreSQL, MariaDB, etc. roles.  
`description`: description of the install.  
`role_name`: name of role to install.

0.1 Contributors
----------------

https://wiki.archlinux.org/index.php/Installation_guide

0.2 Prerequisites
-----------------

* Install scripts
    * Physical machine or virtual machine run by qemu/KVM optionally managed by libvirt.
    * Arch Linux install media (CD for physical machine, ISO or CD for virtual machine).
    * Network access to internet.
    * Access to scripts (either on ISO, CD, network share, via scp, or some other method).
    * bash 4.4 shell (may work on other versions or shells).

* Role scripts
    * Arch Linux install, role should not already have been installed, these scripts are for a new/clean install.
    * Physical machine or virtual machine run by qemu/KVM optionally managed by libvirt.
    * Network access to internet.
    * Access to scripts (either on ISO, CD, network share, via scp, or some other method).
    * bash 4.4 shell (may work on other versions or shells).


1 Tests
=======

See ./doc folder for per script tests and issues.

1.0 Issues
----------

* If installing on disk that already has partitions and file system and new partition table is identical to original then files in file system are not deleted and duplicate entries will be created in config files: /etc/fstab, /etc/ssh/sshd_config, and sudoers file which will lead to errors. This could be viewed either as a use case the script does not cater for, or a safety feature ;-).


2 Usage
=======

Refer to the ./doc directory for individual script documentation.

Scripts must be run as root, requires the 'common' sub folder and sub folder whose name matches script name.

Initial clean install:

1. Boot into Arch Linux install media.  
2. Copy desired script(s) and dependency folders into /tmp directory (or any other directory with write permissions).  
3. Create server configuration file (e.e. use v_svr_base/server.template as a template for server configuration file for v_svr_base.sh script).  
4. [Optional] Create common/mirrorlist based on common/mirrorlist.template to add or uncomment desired mirrors.  
5. Change into directory scripts copied to.  
6. Execute base install script.  
7. Reboot into newly installed operating system and perform post boot tasks.

Role install:

1. Log in to host.  
2. Copy desired script(s) into /tmp directory (or any other directory with write permissions).  
3. Change into directory scripts copied to.  
4. Execute desired role install script.  
5. Perform pre reboot configuration.  
6. Reboot.  
7. Perform post reboot configuration.  
8. Verify working.  


3 Contents
==========

3.0 Folders
-----------

| Folders | Description |
| :--- | :--- |
| common | Files used by multiple scripts |
| doc | Script documentation |
| r_mariadb | Files used by r_mariadb.sh script |
| r_nginx | Files used by r_nginx.sh script |
| v_svr_base | Files used by v_svr_base.sh script |

3.1 Files
---------

| Files | Description |
| :--- | :--- |
| common/functions | Code consumed by multiple scripts. |
| common/list | Wrapper around the 'ls' command which displays details as well as date and time with timezone offset. |
| common/mirrorlist.template | List of mirrors template to download packages from. |
| r_mariadb/mariadb.template | MariaDB database settings template. |
| r_nginx/nginx.conf | Nginx global configuration. |
| r_nginx/nginx.template | Nginx site settings template. |
| r_nginx/override.conf | Nginx service tweaks. |
| r_nginx/www-root | Nginx web site definition. |
| r_nginx/www-root.conf | php-fpm pool configuration. |
| v_svr_base/nftables.config | Initial nftables firewall configuration file (nftables). |
| v_svr_base/server.template | Template server configuration file. |
| v_svr_base/v_svr_base_chroot.sh | Performs post base install chroot configurations. |
| r_mariadb.sh | Installs the [MariaDB](https://wiki.archlinux.org/index.php/MariaDB) and creates database. |
| r_nginx.sh | Installs [Nginx](https://wiki.archlinux.org/index.php/Nginx) and creates root web site. |
| v_svr_base.sh | Performs base install. |
