#!/bin/sh

err()
{
echo >&2 "$(tput bold; tput setaf 1)[-] ERROR: ${*}$(tput sgr0)"
}
msg()
{
  echo "$(tput bold; tput setaf 48)[+] ${*}$(tput sgr0)"
}

check_priv()
{
  if [ "$(id -u)" -ne 0 ]; then
    err "You need to run this as root!"
    exit 1
  fi
}

check_priv

sys_id()
{
    ID=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)
    echo $ID
}

sys_id_like()
{
    IDLIKE=$(awk -F= '$1=="ID_LIKE" { print $2 ;}' /etc/os-release)
    echo $IDLIKE
}

ID="$(sys_id)"
ID_LIKE="$(sys_id_like)"

function yes_no {
    while true; do  
        read -p "$(echo -e "\033[1m\033[38;5;11m$* \e[39m[Y/N] ")" yn
        case $yn in
            [Yy]*) return 0 ;;  
            [Nn]*) err "Aborted" ; exit 1 ;;
        esac
    done
}

detect_os()
{
    base=$(uname | tr "[:upper:]" "[:lower:]")
    
    if [ $base = "linux" ]; then
        if [ "$ID_LIKE" = "debian" ]; then
            msg "Installing Stubby for Debian Based system"
            apt install stubby -y && response="found"
        elif [ "$ID_LIKE" = "rhel fedora" ]; then
            msg "Installing Stubby for CentOS/Fedora"
            dnf install stubby -y && response="found"
	elif [ "$ID" = "fedora" ]; then
            msg "Installing Stubby for Fedora"
            dnf install stubby -y && response="found"
        elif [ "$ID" = "arch" ]; then
            pacman -S stubby --noconfirm && response="found"
            msg "Installing Stubby for Arch Linux"
	elif [ "$ID_LIKE" = "arch" ]; then
            pacman -S stubby --noconfirm && response="found"
            msg "Installing Stubby for Arch Linux"
        elif [ "$ID" = "void" ]; then
            xbps-install -S stubby --yes && response="found"
            msg "Installing Stubby for Void"
        elif [ "$ID" = '"solus"' ]; then
            msg "Installing Stubby for Solus OS"
            eopkg install stubby && response="found"
        elif [ "$ID" = "artix" ]; then
            pacman -S stubby --noconfirm && response="found"

        else
            err "Your system is not supported yet. You have to install the Stubby program manually and rerun the script." ; exit 1
        fi
    else
        err "Your system is not supported yet." ; exit 1
    fi
}

nmcli_conf()
{
	msg "Configuring network manager with nmcli..."
	conn=$(nmcli con show --active | awk -F "  " 'FNR == 2 {print $1}')
	nmcli con mod "$conn" ipv4.dns 127.0.0.1
	nmcli con mod "$conn" ipv6.dns ::1
	nmcli con mod "$conn" ipv4.ignore-auto-dns yes
	nmcli con mod "$conn" ipv6.ignore-auto-dns yes
}

start_servs()
{
	if command -v systemctl &> /dev/null; then
		systemctl enable --now stubby && msg "Stubby started." || err "Cannot start stubby"
		systemctl restart NetworkManager && msg "NetworkManager restarted." || err "Cannot restart NetworkManager"
	elif command -v dinitctl 2&> /dev/null ]; then
		dinitctl enable stubby && msg "Stubby started." || err "Cannot start stubby"
		dinitctl restart NetworkManager && msg "NetworkManager restarted." || err "Cannot restart NetworkManager"
	elif command -v rc-update 2&> /dev/null ]; then
		rc-update add stubby && msg "Stubby started." || err "Cannot start stubby"
		rc-service NetworkManager restart && msg "NetworkManager restarted." || err "Cannot restart NetworkManager"
	elif command -v sv 2&> /dev/null ]; then
		if [ $ID == "artix" ]; then
			ln -s /etc/runit/sv/stubby /run/runit/service && msg "Stubby started." || err "Cannot start stubby"
			sv restart NetworkManager && msg "NetworkManager restarted." || err "Cannot restart NetworkManager"
		else
			ln -s /etc/sv/stubby /run/service && msg "Stubby started." || err "Cannot start stubby"
			sv restart NetworkManager && msg "NetworkManager restarted." || err "Cannot restart NetworkManager"
		fi
	elif command -v s6-rc-update 2&> /dev/null ]; then
		 s6-rc-bundle-update -c /etc/s6/rc/compiled add default stubby && msg "Stubby started." || err "Cannot start stubby"
		 s6-svc -r /run/service/NetworkManager && msg "NetworkManager restarted." || err "Cannot restart NetworkManager"
	elif command -v 66-enable 2&> /dev/null ]; then
		66-enable -t default stubby && msg "Stubby started." || err "Cannot start stubby"
		66-start -t default NetworkManager && msg "NetworkManager restarted." || err "Cannot restart NetworkManager"
	fi
}

set_config_path()
{
    if [ $ID = '"solus"' ]; then
        configfile="/usr/share/defaults/stubby/stubby.yml"
        backupfile="/usr/share/defaults/stubby/stubby.yml.bak"
    else
        configfile="/etc/stubby/stubby.yml"
        backupfile="/etc/stubby/stubby.yml.bak"
    fi
}

set_config_path

check_stubby()  
{
    if ! command -v stubby &> /dev/null; then
        err "Stubby not Found"
        yes_no "[*] Do you want to install stubby?" && detect_os
    elif command -v stubby &> /dev/null; then
        msg "Stubby found!" ; response="found" 
    fi
}
check_stubby

download_configs()
{
    msg "Downloading stubby config file from: [ https://zerologdns.com/stubby.yml ]"
    curl https://zerologdns.com/stubby.yml -o $configfile 2>/dev/null && msg "Success! File is downloaded!" || { err "Cannot download file" ; exit 1; } 
}


backup_configs()
{
    if [ -f "$backupfile" ]; then
        msg "Backup File Found! [$backupfile]"
    else
        mv $configfile $backupfile && msg "Backup file created: [ $backupfile ]"
    fi
}

if [ $response = "found" ]; then
    backup_configs
    download_configs
    nmcli_conf
    start_servs
else
    err "Unexpected response!"
fi
