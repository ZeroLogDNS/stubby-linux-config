#!/bin/bash

err()
{
  echo >&2 "$(tput bold; tput setaf 1)[-] ERROR: ${*}$(tput sgr0)"

  exit 1337
}

msg()
{
  echo "$(tput bold; tput setaf 2)[+] ${*}$(tput sgr0)"
}

check_priv()
{
  if [ "$(id -u)" -ne 0 ]; then
    err "You need to run this as root!"
  fi
}

copy_confs()
{
	msg "Copying config file..."
	cp ./stubby.yml /etc/stubby/stubby.yml
}

check_os()
{
	msg "Checking which distro are use using..."
	os=$(cat /etc/issue | awk '{print $1}')
}

check_pkg()
{
	msg "Checking which package manager are you using and installing stubby if it's not there..."
	if [ apt > /dev/null ]
	then
		apt install stubby
	elif [ pacman > /dev/null ]
	then
		pacman -S stubby
	elif [ xbps-install > /dev/null ]
	then
		xbps-install -S stubby
	fi 
}

nmcli_conf()
{
	msg "Configuring network manager with nmcli..."
	conn=$(nmcli con show --active | awk -F "  " 'FNR == 2 {print $1}')
	nmcli con mod $conn ipv4.dns 127.0.0.1
	nmcli con mod $conn ipv4.ignore-auto-dns yes
}

start_servs()
{
	msg "Starting stubby service..."
	if [ systemctl > /dev/null ]
	then
		systemctl enable --now stubby
	elif [ dinitctl > /dev/null ]
	then
		dinitctl enable stubby
	elif [ rc-update > /dev/null ]
	then
		rc-update add stubby
	elif [ sv > /dev/null ]
		if [ $os == "Artix" ]
		then
			ln -s /etc/runit/sv/stubby /run/runit/service
		else
			ln -s /etc/sv/stubby /run/service
		fi
	elif [ s6-rc-update > /dev/null ]
	then
		 s6-rc-bundle-update -c /etc/s6/rc/compiled add default stubby
	elif [ 66-enable > /dev/null ]
	then
		66-enable -t default stubby
	fi 
}

finish()
{
	msg "All things done, have fun!"
	exit 0
}

check_priv
copy_confs
check_os
check_pkg
nmcli_conf
start_servs
finish
