#!/bin/sh

err()
{
echo >&2 "$(tput bold; tput setaf 1)[-] ERROR: ${*}$(tput sgr0)"
}
msg()
{
  echo "$(tput bold; tput setaf 48)[+] ${*}$(tput sgr0)"
}

info()
{
    echo "$(tput bold; tput setaf 220)[*] ${*}$(tput sgr0)"
}

configlink="https://zerologdns.com/stubby.yml"

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


message()
{
    printf "\n"
    echo "$(tput bold; tput setaf 207)[♥] Thank you for using ZeroLogDNS! $(tput sgr0)"
       
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
        if [[ $ID_LIKE = "debian" || $ID_LIKE = "ubuntu" || $ID = "debian" ]]; then
            msg "Installing Stubby for Debian Based system"
            apt install stubby -y && response="found"
        elif [[ $ID_LIKE = "rhel fedora" || $ID = "fedora" ]]; then
            msg "Installing Stubby for CentOS/Fedora"
            dnf install stubby -y && response="found"
        elif [[ $ID = "arch" || $ID = "artix" || $ID_LIKE = "arch" ]]; then
            pacman -S stubby --noconfirm && response="found"
            msg "Installing Stubby for Arch Linux"
        elif [ $ID = "void" ]; then
            xbps-install -S stubby --yes && response="found"
            msg "Installing Stubby for Void"
        elif [ $ID = '"solus"' ]; then
            msg "Installing Stubby for Solus OS"
            eopkg install stubby && response="found"

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
    test_ipv4=$(nmcli con mod "$conn" ipv4.dns 127.0.0.1 2>&1)
    test_ipv6=$(nmcli con mod "$conn" ipv6.dns ::1 2>&1)


    if [[ "$test_ipv4" == *method=disabled* ]]; then
        info "IPV4 is not enabled. Skip NMCLI IPV4 setting."
    else
        nmcli con mod "$conn" ipv4.dns 127.0.0.1 && nmcli con mod "$conn" ipv4.ignore-auto-dns yes && msg "DNS server is set to 127.0.0.1"
    fi

    if [[ "$test_ipv6" == *method=disabled* ]]; then
        info "IPV6 is not enabled. Skip NMCLI IPV6 setting."
    else
        nmcli con mod "$conn" ipv6.dns ::1 && nmcli con mod "$conn" ipv6.ignore-auto-dns yes && msg "DNS server is set to ::1"
    fi
	
}

check_dns()
{

    info "Testing the DNS configuration."
    if [[ $(curl https://t.zerologdns.net 2>/dev/null | sed -En 's/.*"Response":"([^"]*).*/\1/p') == yes ]]; then
        msg "Success! You are using zerologdns!"
    elif [[ $(curl https://t.zerologdns.net 2>/dev/null | sed -En 's/.*"Response":"([^"]*).*/\1/p') == no ]]; then
        info "You still seem to be using a different DNS server than zerologdns!"
        info "I will try again after sleeping for 5 seconds."
        sleep 5
        if [[ $(curl https://t.zerologdns.net 2>/dev/null | sed -En 's/.*"Response":"([^"]*).*/\1/p') == yes ]]; then
            msg "Success! You are using zerologdns!"
        else
            err "Something went wrong, the setup failed! Try rebooting." 
            err "Contact us on discord: https://zerologdns.com/discord" ; exit 1
        fi

    else
        err "Something went wrong, the setup failed! Try rebooting." 
        err "Contact us on discord: https://zerologdns.com/discord" ; exit 1
    fi
}

start_servs()
{
	if command -v systemctl &> /dev/null; then
        if [[ $1 == "stubby" ]]; then
		    systemctl enable --now stubby && systemctl restart stubby && msg "Stubby started." || err "Cannot start stubby"
        elif [[ $1 == "net" ]]; then
		    systemctl restart NetworkManager && msg "NetworkManager restarted." || err "Cannot restart NetworkManager"
        else
            err "Invalid argument" ; exit 1
        fi
	elif command -v dinitctl 2&> /dev/null; then
        if [[ $1 == "stubby" ]]; then
		    dinitctl enable stubby && dinitctl restart stubby && msg "Stubby started." || err "Cannot start stubby"
        elif [[ $1 == "net" ]]; then
		    dinitctl restart NetworkManager && msg "NetworkManager restarted." || err "Cannot restart NetworkManager"
        else
            err "Invalid argument" ; exit 1
        fi
	elif command -v rc-update 2&> /dev/null; then
        if [[ $1 == "stubby" ]]; then
		    rc-update add stubby && rc-service stubby restart && msg "Stubby started." || err "Cannot start stubby"
        elif [[ $1 == "net" ]]; then
		    rc-service NetworkManager restart && msg "NetworkManager restarted." || err "Cannot restart NetworkManager"
        fi
	elif command -v sv 2&> /dev/null; then
		if [ $ID == "artix" ]; then
            if [[ $1 == "stubby" ]]; then
			    ln -s /etc/runit/sv/stubby /run/runit/service && sv restart stubby && msg "Stubby started." || err "Cannot start stubby"
            elif [[ $1 == "net" ]]; then
                sv restart NetworkManager && msg "NetworkManager restarted." || err "Cannot restart NetworkManager"
            fi
		else
            if [[ $1 == "stubby" ]]; then
			    ln -s /etc/sv/stubby /run/service && sv restart stubby && msg "Stubby started." || err "Cannot start stubby"
            elif [[ $1 == "net" ]]; then
			    sv restart NetworkManager && msg "NetworkManager restarted." || err "Cannot restart NetworkManager"
            fi
		fi
	elif command -v s6-rc-update 2&> /dev/null; then
        if [[ $1 == "stubby" ]]; then
		    s6-rc-bundle-update -c /etc/s6/rc/compiled add default stubby && s6-svc -r /run/service/Stubby && msg "Stubby started." || err "Cannot start stubby"
        elif [[ $1 == "net" ]]; then
		    s6-svc -r /run/service/NetworkManager && msg "NetworkManager restarted." || err "Cannot restart NetworkManager"
        fi
	elif command -v 66-enable 2&> /dev/null; then
        if [[ $1 == "stubby" ]]; then
		    66-enable -t default stubby && 66-start -t default stubby && msg "Stubby started." || err "Cannot start stubby"
        elif [[ $1 == "net" ]]; then
		    66-start -t default NetworkManager && msg "NetworkManager restarted." || err "Cannot restart NetworkManager"
        fi
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

check_stubby()  
{
    if ! command -v stubby &> /dev/null; then
        info "Stubby not Found"
        yes_no "[*] Do you want to install stubby?" && detect_os
    elif command -v stubby &> /dev/null; then
        msg "Stubby found!" ; response="found" 
    fi
}
check_stubby

download_configs()
{
    info "Downloading stubby config file from: [ $configlink ]"
    curl $configlink -o $configfile 2>/dev/null && msg "Success! File is downloaded!" || { err "Cannot download file" ; exit 1; }
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
    set_config_path
    backup_configs
    download_configs
    start_servs "stubby" || exit 1
    nmcli_conf
    start_servs "net" || exit 1
    msg "Waiting for 3 seconds."
    sleep 3
    check_dns
    message
else
    err "Unexpected response!" ; exit 1 ;
fi
