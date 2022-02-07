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
	if [ ! stubby 2@> /dev/null ]
	then
		if [ apt 2&> /dev/null ]
		then
			apt install stubby
		elif [ pacman 2&> /dev/null ]
		then
			pacman -S stubby
		elif [ xbps-install 2&> /dev/null ]
		then
			xbps-install -S stubby
		fi
	fi
}

nmcli_conf()
{
	msg "Configuring network manager with nmcli..."
	conn=$(nmcli con show --active | awk -F "  " 'FNR == 2 {print $1}')
	nmcli con mod "$conn" ipv4.dns 127.0.0.1
	nmcli con mod "$conn" ipv4.ignore-auto-dns yes
}

start_servs()
{
	msg "Starting services..."
	if [ systemctl 2&> /dev/null ]
	then
		systemctl enable --now stubby
		systemctl restart NetworkManager
	elif [ dinitctl 2&> /dev/null ]
	then
		dinitctl enable stubby
		dinitctl restart NetworkManager
	elif [ rc-update 2&> /dev/null ]
	then
		rc-update add stubby
		rc-service NetworkManager restart
	elif [ sv 2&> /dev/null ]
	then
		if [ $os == "Artix" ]
		then
			ln -s /etc/runit/sv/stubby /run/runit/service
			sv restart NetworkManager
		else
			ln -s /etc/sv/stubby /run/service
			sv restart NetworkManager
		fi
	elif [ s6-rc-update 2&> /dev/null ]
	then
		 s6-rc-bundle-update -c /etc/s6/rc/compiled add default stubby
		 s6-svc -r /run/service/NetworkManager
	elif [ 66-enable 2&> /dev/null ]
	then
		66-enable -t default stubby
		66-start -t default NetworkManager
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
