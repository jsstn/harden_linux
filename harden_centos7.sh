#!/bin/bash

#############################################################################
# Version 0.8.0 (27-09-2017)
#############################################################################

#############################################################################
# Copyright 2017 Sebas Veeke. Released under the AGPLv3 license
# See https://github.com/sveeke/harden_linux/blob/master/LICENSE
# Source code on GitHub: https://github.com/sveeke/harden_linux
#############################################################################

#############################################################################
# USER VARIABLES
#############################################################################

HOSTNAME='localhost' # Enter the server's hostname/FQDN (i.e. x.domain.tld)
TIMEZONE='Europe/Amsterdam' # Enter the server's timezone (i.e. 'Europe/Amsterdam')
SSH_PORT='22' # Port 22 is default
ADDITIONAL_PACKAGES='nano wget zip unzip htop' # Remove the ones you don't need

#############################################################################
# SYSTEM VARIABLES
#############################################################################

PACKAGE_MANAGER='/usr/bin/yum' # Enter the path to the package manager
PATH_TO_SSH_CONFIG='/etc/ssh/sshd_config' # /etc/ssh/sshd_config is default

# https://lobste.rs/c/4lfcnm (danielrheath)
#set -e # stop the script on errors
#set -u # unset variables are an error
#set -o pipefail # piping a failed process into a successful one is an arror

#############################################################################
# SCRIPT VARIABLES
#############################################################################

white='\033[1;37m'   # White
green='\e[0;32m'     # Green
red='\e[0;31m'       # Red
nc='\033[0m'         # No color


#############################################################################
# LICENSE AND INTRODUCTION
#############################################################################

clear
echo
echo
echo -e "${white}Harden CentOS 7 server version 1.0 (27-09-2017)"
echo -e "${white}Copyright 2017 Sebas Veeke. Released under the AGPLv3 license"
echo -e "${white}Source code on GitHub: https://github.com/sveeke/harden_linux"
echo
echo -e "${white}This script will configure and harden your CentOS 7 operating system."
echo
echo -e "${white}Chosen configuration:"
echo -e "${white}Hostname:        ${green}${HOSTNAME}"
echo -e "${white}Timezone:        ${green}${TIMEZONE}"
echo -e "${white}SSH port:        ${green}${SSH_PORT}"
echo
echo -e "${white}Press ctrl + c during the script to abort.${nc}"

sleep 3


#############################################################################
# CHECKING REQUIREMENTS
#############################################################################

echo
echo
echo -e "${green}CHECKING REQUIREMENTS${nc}"

# Checking if script runs as root
echo -n "Script is running as root..."
    if [ "$EUID" -ne 0 ]; then
        echo -e "\\t\\t\\t\\t\\t[${red}NO${nc}]"
        echo
        echo "${red}************************************************************************"
	    echo "${red}This script should be run as root. Use su root and run the script again."
	    echo "${red}************************************************************************"
        echo
	    exit
    fi
echo -e "\\t\\t\\t\\t\\t[${green}YES${nc}]"

# Checking CentOS version
echo -n "Running CentOS 7..."
    if [ -e /etc/centos-release ]; then
        CENTOSVER=$(cat /etc/redhat-release | grep -oP '(?<= )[0-9]+(?=\.)')

        if [ "$CENTOSVER" = "7" ]; then
            echo -e "\\t\\t\\t\\t\\t\\t[${green}YES${nc}]"

        else
            echo -e "\\t\\t\\t\\t\\\\t[${red}NO${nc}]"
            echo
            echo "${red}***************************************"
            echo "${red}This script will only work on CentOS 7."
            echo "${red}***************************************"
            echo
            exit 1
        fi
    fi

# Checking internet connection
echo -n "Connected to the internet..."
    if ping -c 1 google.com >> /dev/null 2>&1; then
        echo -e "\\t\\t\\t\\t\\t[${green}YES${nc}]"
    else
        echo -e "\\t\\t\\t\\t\\t[${red}NO${nc}]"
        echo
        echo "${red}**********************************************************************"
        echo "${red}Internet connection is required, please connect to the internet first."
        echo "${red}**********************************************************************"
        echo
        exit
    fi

# Checking whether SElinux is enabled
echo -n "SElinux is enabled..."
    if [ -e /usr/sbin/selinuxenabled ]; then
        echo -e "\\t\\t\\t\\t\\t\\t[${green}YES${nc}]"

        else
        echo -e "\\t\\t\\t\\t\\t\\t[${red}NO${nc}]"
        echo
        echo "${red}***************************************************************************"
	    echo "${red}SElinux should be enabled. Please enable SElinux before running this script"
	    echo "${red}***************************************************************************"
        echo
	    exit 1
    fi


#############################################################################
# UPDATE OPERATING SYSTEM
#############################################################################

echo
echo
echo -e "${green}UPDATING OPERATING SYSTEM${nc}"
echo "Updating repository and upgrading packages..."
${PACKAGE_MANAGER} -y update


#############################################################################
# INSTALL NEW SOFTWARE
#############################################################################

echo
echo
echo -e "${green}INSTALL NEW SOFTWARE${nc}"

# Install required packages
${PACKAGE_MANAGER} -y install chrony yum-cron policycoreutils-python sudo rsyslog

# Install frequently used user software
${PACKAGE_MANAGER} -y install ${ADDITIONAL_PACKAGES}


#############################################################################
# CONFIGURING SERVER
#############################################################################

echo
echo
echo -e "${green}CONFIGURING SERVER${nc}"

# Disable and uninstall unneeded software
echo "Disabling some services..."
systemctl disable --now firewalld

echo "Removing some packages..."
yum -y groupremove "X Window System"

# Configure hostname
echo "Modifying hostname"
hostnamectl set-hostname ${HOSTNAME}

# Configure time
echo "Setting timezone..."
timedatectl set-timezone ${TIMEZONE}
echo -e "Configure NTP..."
timedatectl set-ntp yes

# Configure yum-cron
echo "Configuring yum-cron..."
sed -i s/'update_cmd = default'/'update_cmd = security'/g /etc/yum/yum-cron.conf
sed -i s/'download_updates = no'/'download_updates = yes'/g /etc/yum/yum-cron.conf
sed -i s/'apply_updates = no'/'apply_updates = yes'/g /etc/yum/yum-cron.conf


#############################################################################
# CONFIGURING SSH
#############################################################################

echo
echo
echo -e "${green}CONFIGURING SSH${nc}"

# Create new template
echo "Creating template for sshd_config..."
SSH_TEMP="$(mktemp /tmp/sshd_config.tmp.XXXXXXXXXX)"
unalias cp
cp ${PATH_TO_SSH_CONFIG} ${SSH_TEMP}

# Improve sshd server setting
echo "Configuring sshd_config..."
sed -i -e "s/^.*Port 22.*/Port ${SSH_PORT}/" ${SSH_TEMP}
sed -i -e 's/^.*PermitRootLogin.*/PermitRootLogin no/' ${SSH_TEMP}
sed -i -e 's/^.*PubkeyAuthentication.*/PubkeyAuthentication yes/' ${SSH_TEMP}
sed -i -e 's/^.*PasswordAuthentication.*/PasswordAuthentication no/' ${SSH_TEMP}
sed -i -e 's/^.*PermitEmptyPasswords.*/PermitEmptyPasswords no/' ${SSH_TEMP}
sed -i -e 's/^.*LoginGraceTime.*/LoginGraceTime 60s/' ${SSH_TEMP}
sed -i -e 's/^.*StrictModes.*/StrictModes yes/' ${SSH_TEMP}
sed -i -e 's/^.*MaxAuthTries.*/MaxAuthTries 6/' ${SSH_TEMP}
sed -i -e 's/^.*MaxSessions.*/MaxSessions 6/' ${SSH_TEMP}
sed -i -e 's/^.*AllowTcpForwarding.*/AllowTcpForwarding no/' ${SSH_TEMP}
sed -i -e 's/^.*X11Forwarding.*/X11Forwarding no/' ${SSH_TEMP}
sed -i -e 's/^.*IgnoreRhosts.*/IgnoreRhosts yes/' ${SSH_TEMP}
sed -i -e 's/^.*HostbasedAuthentication.*/HostbasedAuthentication no/' ${SSH_TEMP}
sed -i -e 's/^.*PermitUserEnvironment.*/PermitUserEnvironment no/' ${SSH_TEMP}

# Checking sshd_config
echo "Checking validity of sshd_config "
sshd -t -f ${SSH_TEMP}

if [[ $? -eq  0 ]]; then
    echo "Check succeeded. Replacing sshd_config on server..."
    cp ${SSH_TEMP} ${PATH_TO_SSH_CONFIG}
    echo "Removing temporary sshd_config..."
    rm -f ${SSH_TEMP}

    else
    echo "ERROR SSHD NOT SUCCEEDED"
fi


#############################################################################
# Enabling services
#############################################################################

echo -e "Enabling services..."
systemctl enable --now yum-cron.service
systemctl enable --now systemd-timedated.service
systemctl enable --now chronyd.service
systemctl enable --now rsyslog.service
systemctl enable --now iptables.service
systemctl enable --now sshd.service


#############################################################################
# NOTES
#############################################################################

# Reboot