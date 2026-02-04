#!/bin/bash
#CubeCoders AMP Installer (C) 2019-2025 CubeCoders Limited

function isPresent { command -v "$1" &> /dev/null && echo 1; }
function isFileOpen { lsof "$1" &> /dev/null && echo 1; }
function fetchString { result=$( [ -n "$CURL_IS_PRESENT" ] && curl --ipv4 -s -L "$1" 2>/dev/null || wget --inet4-only -qO- "$1" 2>/dev/null ); echo "${result:-${2:-}}"; }
function urlLink { echo -e "\e]8;;${1}\a${2:-${1}}\e]8;;\a"; }
function prnt { echo -e "$1" | fold -s -w "$cols"; }
function check_version { local distro; distro=$(echo "$1" | tr '[:upper:]' '[:lower:]'); [[ "$distro" == "$(echo "$ID" | tr '[:upper:]' '[:lower:]')" && "$(printf '%s\n' "$3" "$2" | sort -V | head -n1)" != "$3" ]] && echo "AMP requires $1 $3 or newer. You are currently running $VERSION_ID. Please upgrade to $1 $3 and try again." && exit 1; }
function version_ge {
	# Returns 0 (true) if $1 >= $2
	[ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

function desktop_session_running()
{
  if command -v loginctl >/dev/null 2>&1; then
    while read -r sid _; do
      type="$(loginctl show-session "$sid" -p Type --value 2>/dev/null)"
      remote="$(loginctl show-session "$sid" -p Remote --value 2>/dev/null)"
      [ "$remote" = "no" ] && { [ "$type" = "x11" ] || [ "$type" = "wayland" ]; } && return 0
    done < <(loginctl list-sessions --no-legend 2>/dev/null)
  fi

  [ -d /tmp/.X11-unix ] && ls /tmp/.X11-unix/X* >/dev/null 2>&1 && return 0
  [ -d /run/user ] && find /run/user -maxdepth 2 -type s -name 'wayland-*' 2>/dev/null | grep -q . && return 0
  command -v pgrep >/dev/null 2>&1 && pgrep -x Xorg Xwayland gnome-shell kwin_wayland weston sway >/dev/null 2>&1 && return 0

  return 1
}

function mapUpstream {
	case "${ID:-}" in
		ubuntu)
			echo "ubuntu|"${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"|${VERSION_ID:-}"; return 0 ;;
		debian)
			echo "debian|"${VERSION_CODENAME:-}"|${VERSION_ID:-}"; return 0 ;;
		raspbian)
			case "${VERSION_CODENAME:-}" in
				bullseye) echo "debian|bullseye|11"; return 0 ;;
				bookworm) echo "debian|bookworm|12"; return 0 ;;
				trixie) echo "debian|trixie|13"; return 0 ;;
			esac
			return 1 ;;
		kali)
			case "${VERSION_ID%%.*}" in
				2021|2022) echo "debian|bullseye|11"; return 0 ;;
				2023|2024) echo "debian|bookworm|12"; return 0 ;;
				2025|2026) echo "debian|trixie|13"; return 0 ;;
			esac
			return 1 ;;
		linuxmint)
			case "${VERSION_ID%%.*}" in
			    6) echo "debian|bookworm|12"; return 0 ;;
				7) echo "debian|trixie|13"; return 0 ;;
				20) echo "ubuntu|focal|20.04"; return 0 ;;
				21) echo "ubuntu|jammy|22.04"; return 0 ;;
				22) echo "ubuntu|noble|24.04"; return 0 ;;
			esac
			return 1 ;;
		pop)
			case "${VERSION_ID:-}" in
				20.04*) echo "ubuntu|focal|20.04"; return 0 ;;
				22.04*) echo "ubuntu|jammy|22.04"; return 0 ;;
				24.04*) echo "ubuntu|noble|24.04"; return 0 ;;
			esac
			return 1 ;;
		zorin)
			case "${VERSION_ID%%.*}" in
				16) echo "ubuntu|focal|20.04"; return 0 ;;
				17) echo "ubuntu|jammy|22.04"; return 0 ;;
				18) echo "ubuntu|noble|24.04"; return 0 ;;
			esac
			return 1 ;;
		elementary)
			case "${VERSION_ID%%.*}" in
				6) echo "ubuntu|focal|20.04"; return 0 ;;
				7) echo "ubuntu|jammy|22.04"; return 0 ;;
				8) echo "ubuntu|noble|24.04"; return 0 ;;
			esac
			return 1 ;;
		rhel|rocky|almalinux)
			echo "rhel||${VERSION_ID:-}"; return 0 ;;
		fedora|fedora-asahi-remix)
			echo "fedora||${VERSION_ID:-}"; return 0 ;;
		centos|ol|oraclelinux)
			echo "centos||${VERSION_ID:-}"; return 0 ;;
		arch|manjaro|endeavouros|garuda|cachyos)
			echo "arch||${VERSION_ID:-rolling}"; return 0 ;;
		*)
			return 1 ;;
	esac
}

echo "Please wait while GetAMP examines your system and network configuration..."

PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
ARCH=$(arch 2> /dev/null || uname -m)
AMP_SYS_USER=amp
GETAMP_VERSION="3.3.0"

if [ -z "$AMP_ADS_PORT" ]; then AMP_ADS_PORT="8080"; fi
if [ -z "$AMP_ADS_IP" ]; then AMP_ADS_IP="0.0.0.0"; fi
if [ -z "$DNS_SERVER" ]; then DNS_SERVER="8.8.8.8"; fi

echo " - Checking installed packages..."
AMP_USER_EXISTS=$(grep -c :/home/$AMP_SYS_USER: /etc/passwd)
AMPINSTMGR_IS_INSTALLED="$(isPresent ampinstmgr)"
#NFT_IS_PRESENT="$(isPresent nft)"
IPTABLES_IS_PRESENT="$(isPresent iptables)"
UFW_IS_PRESENT="$(isPresent ufw)"
FIREWALLCMD_IS_PRESENT="$(isPresent firewall-cmd)"
SS_IS_PRESENT="$(isPresent ss)"
CURL_IS_PRESENT="$(isPresent curl)"
DIG_IS_PRESENT="$(isPresent dig)"
USERADD_IS_PRESENT="$(isPresent useradd)"
TPUT_IS_PRESENT="$(isPresent tput)"
SELINUX_IS_INSTALLED="$(isPresent setsebool)"
PODMAN_IS_INSTALLED="$(isPresent podman)"
UIDMAP_IS_INSTALLED="$(isPresent newuidmap)"
APT_IS_PRESENT="$(isPresent apt-get)"
YUM_IS_PRESENT="$(isPresent yum)"
PACMAN_IS_PRESENT="$(isPresent pacman)"
ZYPPER_IS_PRESENT="$(isPresent zypper)"
JQ_IS_PRESENT="$(isPresent jq)"
IP_IS_PRESENT="$(isPresent ip)"
#SNAP_IS_PRESENT="$(isPresent snap)"
STATUS_FILE=/opt/cubecoders/amp/shared/WebRoot/installState.json
JAVA_PACKAGES="temurin-8-jdk temurin-11-jdk temurin-17-jdk temurin-21-jdk temurin-25-jdk"
PODMAN_PACKAGES="podman uidmap"

echo " - Checking environment..."
if [[ $EUID -ne 0 ]]; then
	echo "You need root access to run this script! Try running '${BoldText}sudo su${NormalText}' as a separate command first."
	echo "${BoldText}Do not just run the same command again with 'sudo' in front!${NormalText}"
	exit 40
fi

if [ ! "$USERADD_IS_PRESENT" ]; then
	echo "The useradd command isn't available in the current environment. It's missing from \$PATH"
	echo "Try running 'sudo -i' and trying again. Do not re-run the same command with 'sudo' in front."
	exit 130
fi

if [ ! "$TPUT_IS_PRESENT" ]; then
	echo "The tput command isn't available in the current environment. It's missing from \$PATH"
	echo "This usually means you're using an unsupported Linux distribution."
	exit 132
fi

LOG_FILE="$HOME/getamp-$(date +%Y%m%d-%H%M%S).log"
INSTALL_SUMMARY=~/ampsummary.log
date > "$LOG_FILE"

BoldText=$(tput bold 2> /dev/null)
NormalText=$(tput sgr0 2> /dev/null)
UnderlineText=$(tput smul 2> /dev/null)
cols="$(tput cols 2> /dev/null)" || cols=80

if [ "$UFW_IS_PRESENT" ]; then
	UFWSTATUS=$(ufw status)

	if [ "$UFWSTATUS" == "*inactive*" ]; then
		echo "${BoldText}Warning: 'ufw' is installed, but it is not the systems default firewall.${NormalText}"
		echo "AMP will revert to another firewall, but if you change this down the line you may"
		echo "need to manually add/update firewall rules."
		unset UFW_IS_PRESENT
	fi
fi

FIREWALL=none
if [ "$UFW_IS_PRESENT" ]; then FIREWALL=ufw;
elif [ "$FIREWALLCMD_IS_PRESENT" ]; then FIREWALL=firewalld;
elif [ "$IPTABLES_IS_PRESENT" ]; then FIREWALL=iptables; 
fi
# elif [ "$NFT_IS_PRESENT" ]; then FIREWALL=nft; fi; //Disabled for now

echo " - Checking network configuration..."

if [ "$IP_IS_PRESENT" ]; then
	read -r _{,} GATEWAY_IP _ _ _ INTERNAL_IP _ < <(ip r g 1.0.0.0)
	# If the IP address isn't formatted correctly:
	if [[ ! "$INTERNAL_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
		INTERNAL_IP=$(hostname -I | cut -f 1 -d ' ')
	fi
else
	INTERNAL_IP=$(hostname -I | cut -f 1 -d ' ')
fi

if [ "$SS_IS_PRESENT" ]; then
	NS_COMMAND=ss
else
	NS_COMMAND=netstat
fi

if [ ! -f /etc/os-release ]; then
	echo "No OS info available. Missing /etc/os-release"
	exit 20
fi

# shellcheck disable=1091
source /etc/os-release

if [ "$APT_IS_PRESENT" ]; then
	export DEBIAN_FRONTEND=noninteractive
	PM_COMMAND=apt-get
	PM_INSTALL=(install -y --no-remove --no-downgrades)
	PM_UNINSTALL=(remove -y)
	CERTBOT_PACKAGE=python3-certbot-nginx
	LIB32_PACKAGES="libgcc-s1:i386 libstdc++6:i386 zlib1g:i386 libncurses5:i386 libbz2-1.0:i386 libtinfo5:i386 libcurl3-gnutls:i386 libsdl2-2.0-0:i386"
	PREREQ_PACKAGES="dirmngr software-properties-common apt-transport-https gpg-agent dnsutils jq git unzip wget gpg qrencode ca-certificates"
	# If we're on Ubuntu 24.04 or newer: 
	if [ "$ID" = "ubuntu" ] && version_ge "$VERSION_ID" "24.04"; then
		echo " - Updating packages list for Ubuntu >= 24.04..."
		LIB32_PACKAGES="libgcc-s1:i386 libstdc++6:i386 zlib1g:i386 libncurses6:i386 libbz2-1.0:i386 libtinfo6:i386 libcurl3t64-gnutls:i386 libsdl2-2.0-0:i386"
	fi
	# Debian 13 or newer
	if [ "$ID" = "debian" ] && version_ge "$VERSION_ID" "13"; then
		echo " - Updating packages list for Debian >= 13..."
		PREREQ_PACKAGES="dirmngr apt-transport-https gpg-agent dnsutils jq git unzip wget gpg qrencode libicu76 ca-certificates"
		LIB32_PACKAGES="libgcc-s1:i386 libstdc++6:i386 zlib1g:i386 libncurses6:i386 libbz2-1.0:i386 libtinfo6:i386 libcurl3t64-gnutls:i386 libsdl2-2.0-0:i386"
	fi
	
	PM_LOCK_FILE="/var/lib/dpkg/lock"
	INSTALL_IN_PROGRESS=$(isFileOpen $PM_LOCK_FILE)

	if [ "$FIREWALL" == "iptables" ] && [ ! -d /etc/iptables ]; then
		PREREQ_PACKAGES="$PREREQ_PACKAGES iptables-persistent"
	fi
elif [ "$YUM_IS_PRESENT" ]; then
	PM_COMMAND=yum
	PM_INSTALL=(-y install)
	PM_UNINSTALL=(-y remove)
	LIB32_PACKAGES="glibc.i686 libstdc++.i686 ncurses-libs.i686"
	PREREQ_PACKAGES="wget tmux socat unzip git bind-utils tar jq qrencode libicu"
	CERTBOT_PACKAGE=python3-certbot-nginx
	PM_LOCK_FILE="/var/run/yum.pid"
	INSTALL_IN_PROGRESS=$(isFileOpen $PM_LOCK_FILE)
elif [ "$PACMAN_IS_PRESENT" ]; then
	PM_COMMAND=pacman
	PM_INSTALL=(-S --noconfirm)
	LIB32_PACKAGES="lib32-glibc lib32-gcc-libs"
	PREREQ_PACKAGES="wget tmux socat unzip git dnsutils tar jq qrencode"
	CERTBOT_PACKAGE=certbot-nginx
	JAVA_PACKAGES="jre8-openjdk-headless jre11-openjdk-headless jre17-openjdk-headless jre21-openjdk-headless jre-openjdk-headless"

	if [ "$ARCH" != "x86_64" ]; then
		echo "AMP only supports aarch64 on Debian and RHEL/CentOS based distros at this time."
		exit
	fi
elif [ "$ZYPPER_IS_PRESENT" ]; then
    PM_COMMAND=zypper
    PM_INSTALL=(install -y --no-force-resolution)
    PM_UNINSTALL=(remove -y)
    LIB32_PACKAGES="glibc-32bit libstdc++6-32bit"
    PREREQ_PACKAGES="wget tmux socat unzip git bind-utils tar jq qrencode libicu"
    CERTBOT_PACKAGE=python3-certbot-nginx
    PM_LOCK_FILE="/var/run/zypp.pid"
    INSTALL_IN_PROGRESS=$(isFileOpen $PM_LOCK_FILE)

    # openSUSE: require x86_64 or aarch64 similar policy
    if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "aarch64" ]; then
        echo "AMP is only supported on x86_64 and aarch64 systems. You are running $ARCH"
        exit 64
    fi
else
	echo "This system doesn't appear to be supported. No supported package manager (apt/yum/pacman) was found."
	echo "Automated installation is only available for Debian, RHEL and Arch based distributions, including Ubuntu and CentOS."
	echo "$NAME is not a supported distribution at this time."
	exit
fi

if [ "$ID" == "photon" ]; then
	PREREQ_PACKAGES="wget tmux socat unzip git bindutils tar jq sqlite-devel"
	FORCE_PODMAN=1
fi

if [ "$INSTALL_IN_PROGRESS" ]; then
	echo "Your package manager is currently performing another installation."
	echo "Please wait for that to finish before installing AMP."
	echo
	echo "Info: A lock is open on $PM_LOCK_FILE"
	exit 131
fi

EXTERNAL_IP=$(fetchString "https://api.ipify.org/")

# Check if EXTERNAL_IP is either empty or doesn't look like a valid IP address

if [[ -z "$EXTERNAL_IP" || ! "$EXTERNAL_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(:[0-9]+)?$|^([a-fA-F0-9]{1,4}:){7}[a-fA-F0-9]{1,4}$ ]]; then
  # Try another provider
  EXTERNAL_IP=$(fetchString "https://ipecho.io/plain")
fi

echo " - Detecting network type..."

export EXTERNAL_IP
NETWORK_TYPE=$([[ "$INTERNAL_IP" == "$EXTERNAL_IP" ]] && echo "Direct" || echo "NAT")
NETWORK_TYPE=$(traceroute -m 4 google.com 2> /dev/null | grep -ic " 100.64." >/dev/null && echo "CGNAT" || echo "$NETWORK_TYPE")
export NETWORK_TYPE

syspass=
ampuser=
amppass=

if [ -z "$SKIPLOCALECHECK" ]; then
  if [[ (-n "$LANG" || -n "$LC_ALL") && ! ( "$LANG" =~ \.(UTF-8|utf8)$ || "$LC_ALL" =~ \.(UTF-8|utf8)$ ) ]]; then
	echo "System locale is not a UTF-8 compatible locale."
	echo "Please update your system locale to a UTF-8 one and reboot before running this script."
	if [ "$APT_IS_PRESENT" ]; then
	  prnt "You can do this by running 'dpkg-reconfigure locales && locale-gen' as root and making sure a UTF-8 locale for your region/language is selected. On some systems it may be 'update-locale LANG=en_GB.utf8' instead."
	else
	  prnt "Please consult your distribution's documentation for how to configure your system for a UTF-8 compatible locale."
	fi
	echo "It may be necessary to log out and log in again for locale changes to take effect."
	exit 30
  fi
fi

export TERM=xterm

check_version "Ubuntu" "20.04"
check_version "Debian" "10"
check_version "CentOS" "8"

if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "aarch64" ]; then
	echo "AMP is only supported on x86_64 and aarch64 systems. You are running $ARCH."
	exit 64
fi

if [ "$ARCH" == "aarch64" ]; then
	reposuffix=$ARCH/
	echo
	echo "Platform information"
	echo
	echo "You are installing AMP on an aarch64 system."
	echo
	prnt "This means that many game servers will not run on this system, or may only run via CPx2 emulation which may reduce performance."
	echo 
	echo "For more information on aarch64 compatible titles, please see:"
	urlLink "https://discourse.cubecoders.com/docs?topic=1870&utm_term=aarch64"
	echo
	read -n 1 -s -r -p "Press enter to continue."
fi

if [ "$(mount | grep -icE '^tmpfs\s+\/tmp\s+.*?noexec.+$')" -gt 0 ]; then
	echo "Your /tmp filesystem has the 'noexec' flag set. Please edit your /etc/fstab file to not have the noexec flag on /tmp"
	echo "You will need to reboot your system after making this change"
	exit 120
fi

if [ -f /var/run/scw-metadata.cache ]; then
	CLOUD_PROVIDER=Scaleway
	EXT_HOSTNAME=$(grep -oP '^ID=\K.+$' /var/run/scw-metadata.cache).pub.cloud.scaleway.com
else
	if [ "$(grep -ic ovh /etc/resolv.conf)" -gt 0 ]; then CLOUD_PROVIDER=OVH;
	elif [ "$(grep -ic hetzner /var/run/cloud-init/instance-data.json &> /dev/null || echo 0)" -gt 0 ]; then CLOUD_PROVIDER="Hetzner";
	elif [ "$(grep -ic linode /etc/resolv.conf)" -gt 0 ]; then CLOUD_PROVIDER="Linode";
	elif [ "$(grep -ic oracle /etc/resolv.conf)" -gt 0 ]; then CLOUD_PROVIDER="Oracle";
	elif [ "$(grep -ic ec2 /etc/resolv.conf)" -gt 0 ]; then CLOUD_PROVIDER="Amazon";
	elif [ -f /var/run/cloud-init/cloud-id-azure ]; then CLOUD_PROVIDER="Azure";
	elif [ -f /etc/cloud/digitalocean.info ]; then CLOUD_PROVIDER="DigitalOcean"; fi

	if [ "$DIG_IS_PRESENT" ]; then
		FQDN=$(hostname -f)
		if [ "$FQDN" != "localhost" ]; then
			fqdnip=$(dig "$DNS_SERVER" +short "$FQDN" | tail -n 1)

			if [ "$fqdnip" == "$EXTERNAL_IP" ]; then
				EXT_HOSTNAME=$FQDN
			fi
		fi

		if [ -z "$EXT_HOSTNAME" ]; then
			digout=$(dig "$DNS_SERVER" +short -x "$EXTERNAL_IP" | tail -n 1)
			if [ -n "$digout" ]; then
				reverse="${digout::-1}"
				verify=$(dig "$DNS_SERVER" +short "$digout" | tail -n 1)

				if [ "$verify" == "$EXTERNAL_IP" ]; then
					EXT_HOSTNAME=$reverse
				fi
			fi
		fi
	elif [[ "$FQDN" =~ ^.+?(\..+)+$ ]]; then
		EXT_HOSTNAME=$FQDN
	fi

	if [ "$CLOUD_PROVIDER" == "Oracle" ] && [ -z "$USE_ANSWERS" ]; then
		echo
		echo "GetAMP has detected that you are using Oracle Cloud."
		echo
		prnt "Extra steps are required to run AMP on Oracle Cloud, if you have not yet done this, ${BoldText}press CTRL+C now to stop the setup${NormalText} and consult the documentation at ${UnderlineText}$(urlLink "https://ccl.sh/2307")${NormalText} before continuing."
		echo
		prnt "Make sure you are using ${BoldText}Ubuntu 22.04 or newer${NormalText} as per the guide. Older versions are not supported on ARM hardware."
		echo
		read -n 1 -s -r -p "Press enter to continue if you have already done this."
	fi
fi

export EXT_HOSTNAME

function showSystemInfo {
	echo "Distribution        : $ID $VERSION_ID"
	echo "Platform            : $ARCH"
	if [ -z "$PRIVATE" ]; then
		echo "Internal IP address : $INTERNAL_IP"
		echo "External IP address : $EXTERNAL_IP"
		if [ "$NETWORK_TYPE" == "NAT" ] && [ -n "$GATEWAY_IP" ]; then echo "Gateway IP address  : $GATEWAY_IP"; fi
	fi
	echo "Network type        : $NETWORK_TYPE"
	echo "Detected Firewall   : $FIREWALL"
	if [ -n "$EXT_HOSTNAME" ]; then echo "External Host name  : $EXT_HOSTNAME"; fi
	if [ -n "$CLOUD_PROVIDER" ]; then echo "Service Provider    : $CLOUD_PROVIDER"; fi
	echo "System Locale       : $LANG"
	echo "Package Manager     : $PM_COMMAND"
}

function configureDarkMagicNew {
	if [[ "$ARCH" != "aarch64" ]]; then
		echo "CPx2 is only applicable to aarch64 systems."
		exit
	fi

	if [[ ! "$ID" =~ ^(ubuntu|debian)$ ]]; then
		echo "CPx2 is only supported on Ubuntu and Debian at this time."
		exit
	fi
	
	echo "Installing CPx2..."
	{
		dpkg --add-architecture armhf
		$PM_COMMAND update
		if { [[ "$ID" == "ubuntu" ]] && version_ge "$VERSION_ID" "24.04"; } || { [[ "$ID" == "debian" ]] && version_ge "$VERSION_ID" "13"; }; then
			ARM_PACKAGES="libgcc-s1:armhf libstdc++6:armhf zlib1g:armhf libbz2-1.0:armhf libcurl4t64:armhf libcurl3t64-gnutls:armhf libncurses6:armhf libtinfo6:armhf libsdl2-2.0-0:armhf libssl3t64:armhf"
		else
			ARM_PACKAGES="libgcc-s1:armhf libstdc++6:armhf zlib1g:armhf libbz2-1.0:armhf libcurl4:armhf libcurl3-gnutls:armhf libncurses5:armhf libtinfo5:armhf libsdl2-2.0-0:armhf libssl3:armhf"
		fi
		# shellcheck disable=SC2086
		$PM_COMMAND "${PM_INSTALL[@]}" $ARM_PACKAGES binfmt-support
		
		install -d -m 0755 /usr/share/keyrings
		wget -qO- "https://pi-apps-coders.github.io/box86-debs/KEY.gpg" | gpg --dearmor --yes -o /usr/share/keyrings/box86-archive-keyring.gpg
		wget -qO- "https://pi-apps-coders.github.io/box64-debs/KEY.gpg" | gpg --dearmor --yes -o /usr/share/keyrings/box64-archive-keyring.gpg
		if { [[ "$ID" == "ubuntu" ]] && version_ge "$VERSION_ID" "22.04"; } || { [[ "$ID" == "debian" ]] && version_ge "$VERSION_ID" "12"; }; then
			[[ -f /etc/apt/sources.list.d/box86.list ]] && rm -f /etc/apt/sources.list.d/box86.list
			[[ -f /etc/apt/sources.list.d/box64.list ]] && rm -f /etc/apt/sources.list.d/box64.list
			printf "Types: deb\nURIs: https://Pi-Apps-Coders.github.io/box86-debs/debian\nSuites: ./\nSigned-By: /usr/share/keyrings/box86-archive-keyring.gpg" | tee /etc/apt/sources.list.d/box86.sources >/dev/null
			printf "Types: deb\nURIs: https://Pi-Apps-Coders.github.io/box64-debs/debian\nSuites: ./\nSigned-By: /usr/share/keyrings/box64-archive-keyring.gpg" | tee /etc/apt/sources.list.d/box64.sources >/dev/null
		else
			echo "deb [signed-by=/usr/share/keyrings/box86-archive-keyring.gpg] https://Pi-Apps-Coders.github.io/box86-debs/debian ./" | tee /etc/apt/sources.list.d/box86.list > /dev/null
			echo "deb [signed-by=/usr/share/keyrings/box64-archive-keyring.gpg] https://Pi-Apps-Coders.github.io/box64-debs/debian ./" | tee /etc/apt/sources.list.d/box64.list > /dev/null
		fi
		$PM_COMMAND update

		MODEL=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || grep -m1 'Model' /proc/cpuinfo || true)
		case "$MODEL" in
			*"Raspberry Pi 4"*) BOX_PACKAGES="box86-rpi4arm64:armhf box64-rpi4arm64" ;;
			*"Raspberry Pi 3"*) BOX_PACKAGES="box86-rpi3arm64:armhf box64-rpi3arm64" ;;
			*) BOX_PACKAGES="box86-generic-arm:armhf box64-generic-arm" ;;
		esac

    	if ! mountpoint -q /proc/sys/fs/binfmt_misc; then
			mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc
		fi
		$PM_COMMAND "${PM_INSTALL[@]}" $BOX_PACKAGES
		if [[ ! -f /proc/sys/fs/binfmt_misc/box86 ]] && [[ ! -f /proc/sys/fs/binfmt_misc/x86 ]]; then
			echo ":box86:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x03\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/local/bin/box86:" | tee /proc/sys/fs/binfmt_misc/register >/dev/null
		fi
		if [[ ! -f /proc/sys/fs/binfmt_misc/box64 ]]; then
			echo ":box64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00:\xff\xff\xff\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/local/bin/box64:" | tee /proc/sys/fs/binfmt_misc/register >/dev/null
		fi
		systemctl restart systemd-binfmt
	} &>> "$LOG_FILE"
}

function showWelcome {
	if [ -z "$USE_ANSWERS" ]; then
		clear
		echo
		echo "GetAMP v$GETAMP_VERSION, ©2019-$(date +%Y) CubeCoders Limited"
		prnt "AMP QuickStart installation script for Debian, RHEL and Arch based GNU/Linux distributions"
		prnt "This installer will perform the following:"
		echo 
		echo " * Install any pending system updates"
		echo " * Install any prerequisites and dependencies via your systems package manager"
		echo " * Add the CubeCoders repository to your system to keep AMP updated"
		echo " * Install AMP and create a default management instance on port $AMP_ADS_PORT"
		echo " * Create any firewalls necessary to allow you to connect to AMP"
		echo " * Configure the default AMP instance to start on boot"
		echo 
		echo "Press CTRL+C to cancel installation."
		echo
		prnt "It is safe to cancel this installation at any point. You can run the install script again, and the script will skip any steps it has already completed."
		echo
	fi
	showSystemInfo
	echo
}

function promptForSystemUser {
	if [ -n "$USE_ANSWERS" ]; then
		syspass=$ANSWER_SYSPASSWORD
		return
	fi

	syspass=$(cat /proc/sys/kernel/random/uuid)
}

function promptForAMPUser {
	if [ -n "$USE_ANSWERS" ]; then
		ampuser=$ANSWER_AMPUSER
		amppass=$ANSWER_AMPPASS
		return
	fi

	echo "Enter new login details for use with AMP."
	echo "These are the login details you will use to log into AMPs web interface."
	echo
	read -rp "Username [admin]: " ampuser
	ampuser=${ampuser:-admin}
	read -rsp "Password: " amppass
	if [ -z "$amppass" ]; then
		echo "You must provide a password for the AMP login user."
		exit 60
	fi
	echo
	read -rsp "Confirm Password:" amppassconfirm
	echo
	echo

	if [ "$syspass" == "$amppass" ]; then
		echo "The system and AMP passwords cannot be the same. Aborting."
		exit 70
	fi

	if [ "$amppass" != "$amppassconfirm" ]; then
		echo "Confirmation password does not match. Aborting."
		exit 80
	fi

	amppass=base64:$(echo -n "$amppass" | base64)
	ampuser=$(printf '%q' "$ampuser")
}

function promptForDeps {
	if [ -n "$FORCE_PODMAN" ]; then
		installPodman=y
		return; 
	fi

	if [ -n "$USE_ANSWERS" ]; then
		installJava=$ANSWER_INSTALLJAVA
		install32BitLibs=${ANSWER_INSTALL32BITLIBS:-${ANSWER_INSTALLSRCDSLIBS:-}}
		installPodman=$ANSWER_INSTALLPODMAN
		return
	fi

	echo "Would you like to isolate your AMP instances by running them inside Podman containers?"
	prnt "This provides an additional layer of protection at the expense of a minor performance impact. It is strongly recommended if you are going to allow untrusted users access to AMP."
	echo
	prnt "Using Podman is also strongly recommended for running some applications, as it removes the requirement to install additional dependencies on the host."
	prnt "If you are using a Desktop environment / GUI on this system, you should use this option to avoid package conflicts."
	read -rp "[y/N] " installPodman
	installPodman=${installPodman:-n}
	echo
	echo

	echo "Will you be running Minecraft servers on this installation?"
	echo "If selected, this installs the required versions of Java."
    echo "If you selected to install Docker, and intend to run Minecraft servers only inside Docker containers, you do not need to select this option. It is however useful for flexibility."
	read -rp "[Y/n] " installJava
	installJava=${installJava:-y}
	echo
	echo

	if [ "$ARCH" == "x86_64" ]; then
		echo "Will you be running applications that rely on SteamCMD (Rust, ARK, CS2, Palworld, etc) on this installation?"
		echo "If selected, this will install the required additional 32-bit libraries."
        echo "If you selected to install Docker, and intend to run such applications only inside Docker containers, you do not need to select this option. It is however useful for flexibility."
		read -rp "[Y/n] " install32BitLibs
		install32BitLibs=${install32BitLibs:-y}
		echo
		echo
	fi

	if [ "$ARCH" == "aarch64" ] && { [ "$ID" == "ubuntu" ] || [ "$ID" == "debian" ]; }; then
		echo "Would you like to configure this system for cross-platform execution (CPx2)?"
		echo "CPx2 involves installing Box86 and Box64 on this system from the Pi-Apps-Coders repositories (https://github.com/Pi-Apps-Coders)."
		prnt "This allows AMP to run a limited number of x86_64 applications on aarch64 systems via emulation - see https://discourse.cubecoders.com/t/aarch64-arm64-compatibility/1870. But this comes at a performance impact."
		echo
		read -rp "[y/N] " installDarkMagic
		installDarkMagic=${installDarkMagic:-n}
		echo
		echo
	fi
}

function promptForHTTPS {
	if [ -n "$USE_ANSWERS" ]; then
		setupnginx=$ANSWER_HTTPS
		nginxdomain=$EXT_HOSTNAME
		nginxemail=$ANSWER_EMAIL
		return
	fi

	apache_is_present=$(isPresent apache2)

	echo "Would you like AMP to be configured for use with HTTPS?"
	if ! [ "$apache_is_present" ]; then
		echo 
		prnt "This will install nginx on your system and requires that you do not use any other web servers such as Apache on this system."
	fi
	echo
	prnt "If nginx is already set up, this will add a new site configuration for AMP and will not modify any existing configurations. Otherwise, nginx will be installed."
	echo
	echo "This will also create firewall rules to open ports 80 (HTTP) and 443 (HTTPS)"
	if [ "$SELINUX_IS_INSTALLED" ]; then
		echo "and the appropriate selinux rules to allow nginx to act as a reverse proxy."
	fi
	echo "You also must own a domain name that resolves to ${BoldText}$EXTERNAL_IP${NormalText} (Your external IP)"
	if [ -n "$EXT_HOSTNAME" ]; then
		echo
		echo "GetAMP has automatically detected an externally resolvable domain of $EXT_HOSTNAME"
		echo "You can either use this or you can supply your own subdomain at the next step."
	fi
	echo
	echo "${BoldText}Do not choose this option if you do not already own a domain.${NormalText}"
	echo 
	prnt "Using this facility requires that you read and accept the Let's Encrypt terms at ${UnderlineText}$(urlLink "https://letsencrypt.org/documents/LE-SA-v1.2-November-15-2017.pdf")${NormalText}"
	echo
	echo "Enable HTTPS?"
	read -rp "[y/N] " setupnginx
	echo
	echo

	if [[ "$setupnginx" =~ ^[Yy]$ ]]; then
		AMP_ADS_IP="127.0.0.1"
		if [ "$apache_is_present" ]; then
			echo "Apache2 is installed, which will conflict with nginx as required for AMPs reverse proxy - Aborting."
			echo "Either remove Apache2 and try again, or re-run this script and select 'No' when asked if you wish to use HTTPS"
			exit 90
		fi

		echo "Please specify which domain you wish to use."
		echo "${BoldText}You should use a subdomain that is only going to be used for AMP.${NormalText}"
		echo "E.g. ${BoldText}amp.mydomain.com${NormalText}"

		if [ -n "$EXT_HOSTNAME" ]; then
			read -rp "Domain [$EXT_HOSTNAME]: " nginxdomain
			nginxdomain=${nginxdomain:-$EXT_HOSTNAME}
		else
			read -rp "Domain: " nginxdomain
		fi

		if [ -z "$nginxdomain" ]; then
			echo "Using HTTPS requires that you specify a domain. Do not select this option if you don't have one."
			exit 91
		fi

		echo "Please enter your email address (Optional)"
		echo "Let's Encrypt will send important certificate notifications here."
		read -rp "Email: " nginxemail

		if [ "$NETWORK_TYPE" == "NAT" ]; then
			echo "GetAMP has detected that you are currently behind a NAT."
			echo "Please forward ports 80 and 443 TCP to $INTERNAL_IP if you have not already done so."
			read -n 1 -s -r -p "Press enter to continue once you have done this."
		fi
	fi
}

function createUser {
	echo "Creating system user..."
	
	if ! useradd -G tty -d /home/"$AMP_SYS_USER" -m "$AMP_SYS_USER" -s /bin/bash &>> "$LOG_FILE"; then
		echo "Failed to add system user. Aborting..."
		promptLogUpload
		exit 11
	fi
	echo "$AMP_SYS_USER:$syspass" | chpasswd
    install -d -m 0700 -o $AMP_SYS_USER -g $AMP_SYS_USER "/run/user/$(id -u $AMP_SYS_USER)"
	{
		echo "export TERM=xterm"
		# shellcheck disable=2028
		echo 'export PS1=" \[\e[30;41m\]\[\e[m\]\[\e[37;41m\] CubeCoders AMP \[\e[m\]\[\e[31;44m\]\[\e[m\]\[\e[44m\] 💻\u\[\e[m\]\[\e[44m\]@\[\e[m\]\[\e[44m\]\h \[\e[m\]\[\e[34;42m\]\[\e[m\]\[\e[30;42m\] 📁\w \[\e[m\]\[\e[32;40m\]\[\e[m\] "'
		# shellcheck disable=2028
		echo "alias sudo=\"echo \\\"You cannot use sudo while logged in as the 'amp' user, you need to be logged in as an administrator/root user do to that.\\\" && false\""
		echo "alias htop=\"htop -u $AMP_SYS_USER\""
        echo "export XDG_RUNTIME_DIR=\"/run/user/$(id -u $AMP_SYS_USER)\""
	} >> /home/$AMP_SYS_USER/.profile
	mkdir -p "/home/$AMP_SYS_USER/.config/htop/"
	cat <<EOF > /home/$AMP_SYS_USER/.config/htop/htoprc
# Beware! This file is rewritten by htop when settings are changed in the interface.
# The parser is also very primitive, and not human-friendly.
fields=0 48 39 46 47 49 1
sort_key=46
sort_direction=-1
tree_sort_key=0
tree_sort_direction=1
hide_kernel_threads=1
hide_userland_threads=1
shadow_other_users=0
show_thread_names=0
show_program_path=1
highlight_base_name=0
highlight_megabytes=1
highlight_threads=1
highlight_changes=0
highlight_changes_delay_secs=5
find_comm_in_cmdline=1
strip_exe_from_cmdline=1
show_merged_command=0
tree_view=0
tree_view_always_by_pid=0
header_margin=1
detailed_cpu_time=0
cpu_count_from_one=0
show_cpu_usage=1
show_cpu_frequency=0
show_cpu_temperature=0
degree_fahrenheit=0
update_process_names=0
account_guest_in_cpu_meter=0
color_scheme=0
enable_mouse=1
delay=15
left_meters=LeftCPUs2 Memory Swap Clock
left_meter_modes=1 1 1
right_meters=RightCPUs2 Tasks LoadAverage Uptime
right_meter_modes=1 2 2 2
EOF
	chown $AMP_SYS_USER:$AMP_SYS_USER "/home/$AMP_SYS_USER/.profile" 2> /dev/null
	chown -R $AMP_SYS_USER:$AMP_SYS_USER "/home/$AMP_SYS_USER/.config" 2> /dev/null
	if [ "$ID" == "photon" ]; then
		chown -R $AMP_SYS_USER:users "/home/$AMP_SYS_USER/.config" 2> /dev/null
	fi
}

function updateSystem {
	echo "Updating System..."
	if [ "$APT_IS_PRESENT" ]; then
		apt-get update &>> "$LOG_FILE"
		apt-get upgrade -y &>> "$LOG_FILE"
	elif [ "$YUM_IS_PRESENT" ]; then
		yum update -y &>> "$LOG_FILE"
	elif [ "$PACMAN_IS_PRESENT" ]; then
		sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
		pacman -Syu --noconfirm &>> "$LOG_FILE"
	fi
}

function installJava {
	IFS='|' read -r BASE_ID BASE_SUITE BASE_VERSION_ID < <(mapUpstream)
	JAVA_INSTALL_AVAILABLE=false

	if [[ "$BASE_ID" =~ ^(ubuntu|debian)$ ]]; then
		if wget -q --spider https://packages.adoptium.net/ui/native/deb/dists/$BASE_SUITE/ >/dev/null 2>&1; then
			JAVA_INSTALL_AVAILABLE=true
			echo "Adding Adoptium APT repository and installing Adoptium Temurin Java LTS versions..."
			if { [[ "$BASE_ID" == "ubuntu" ]] && version_ge "$BASE_VERSION_ID" "22.04"; } || { [[ "$BASE_ID" == "debian" ]] && version_ge "$BASE_VERSION_ID" "12"; }; then
				printf "Types: deb\nURIs: https://packages.adoptium.net/artifactory/deb\nSuites: %s\nComponents: main\nSigned-By: /etc/apt/keyrings/adoptium.gpg\n" "$BASE_SUITE" | tee /etc/apt/sources.list.d/adoptium.sources >/dev/null
			else
				echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $BASE_SUITE main" \
				| tee /etc/apt/sources.list.d/adoptium.list > /dev/null
			fi
			{
				install -d -m 0755 /usr/share/keyrings
				wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /usr/share/keyrings/adoptium.gpg
				$PM_COMMAND update
			} &>> "$LOG_FILE"
		fi
	elif [[ "$ID" =~ ^(amazonlinux|centos|fedora|opensuse|oraclelinux|rhel|rocky|sles|almalinux|fedora-asahi-linux)$ ]]; then
		REPO_ID=$([[ "$ID" =~ ^(almalinux|fedora-asahi-linux)$ ]] && echo "$BASE_ID" || echo "$ID")
		if wget -q --spider https://packages.adoptium.net/ui/native/rpm/$REPO_ID/${VERSION_ID%%.*}/$ARCH/ >/dev/null 2>&1; then
			JAVA_INSTALL_AVAILABLE=true
			echo "Adding Adoptium RPM repository and installing Adoptium Temurin Java LTS versions..."
			{
  				cat <<EOF
[Adoptium]
name=Adoptium
baseurl=https://packages.adoptium.net/artifactory/rpm/$REPO_ID/${VERSION_ID%%.*}/$ARCH
enabled=1
gpgcheck=1
gpgkey=https://packages.adoptium.net/artifactory/api/gpg/key/public
EOF
			} > /etc/yum.repos.d/adoptium.repo 2>>"$LOG_FILE"
		fi
	elif [[ "$BASE_ID" =~ "arch" ]]; then
		JAVA_INSTALL_AVAILABLE=true
		echo "Installing OpenJDK LTS versions from your system repositories..."
    fi

	if ! $JAVA_INSTALL_AVAILABLE; then
		echo "Automatic Java installation is not supported on your system at this time. Please investigate installing the required Java versions manually after setup completes."
		echo "Continuing without installing Java..."
		return
	else
			# shellcheck disable=SC2086
			$PM_COMMAND "${PM_INSTALL[@]}" $JAVA_PACKAGES &>> "$LOG_FILE"
	fi
}

function installDocker {
	echo ""
	
	if [[ "$DOCKER_IS_INSTALLED" ]]; then
		echo "Docker is already installed."
		echo "If you didn't install Docker from the official Docker repositories, then it may not operate correctly with AMP."
		echo "Do you want to remove the existing Docker installation and install Docker from the official Docker repositories, if available for your system?"
		echo "This will also stop any existing running Docker containers."
		read -rp "[y/N] " reInstallDocker
		reInstallDocker=${reInstallDocker:-n}
		if [[ ! "$reInstallDocker" =~ ^[Yy]$ ]]; then
			echo "Skipping Docker re-installation..."
			{
				usermod -a -G docker $AMP_SYS_USER
				systemctl enable docker
				systemctl start docker
			} &>> "$LOG_FILE"
			return
		fi
	fi

	echo "Installing Docker..."

	IFS='|' read -r BASE_ID BASE_SUITE BASE_VERSION_ID < <(mapUpstream)
	DOCKER_REPO_AVAILABLE=false

    case "$BASE_ID" in
        ubuntu|debian)
			if wget -q --spider https://download.docker.com/linux/$BASE_ID/dists/$BASE_SUITE/ >/dev/null 2>&1; then
				DOCKER_REPO_AVAILABLE=true
				if [[ "$reInstallDocker" =~ ^[Yy]$ ]]; then
					REMOVE_DOCKER_PACKAGES="docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc"
				fi
				[[ -f /usr/share/keyrings/download.docker.com.gpg ]] && rm -f /usr/share/keyrings/download.docker.com.gpg >/dev/null 2>&1
				[[ -f /etc/apt/sources.list.d/download.docker.com.list ]] && rm -f /etc/apt/sources.list.d/download.docker.com.list >/dev/null 2>&1
				[[ -f /etc/apt/sources.list.d/docker.list ]] && rm -f /etc/apt/sources.list.d/docker.list >/dev/null 2>&1
				if { [[ "$BASE_ID" == "ubuntu" ]] && version_ge "$BASE_VERSION_ID" "22.04"; } || { [[ "$BASE_ID" == "debian" ]] && version_ge "$BASE_VERSION_ID" "12"; }; then
					printf "Types: deb\nURIs: https://download.docker.com/linux/%s\nSuites: %s\nComponents: stable\nArchitectures: %s\nSigned-By: /usr/share/keyrings/docker.asc\n" "$BASE_ID" "$BASE_SUITE" "$(dpkg --print-architecture)" \
					| tee /etc/apt/sources.list.d/docker.sources > /dev/null
				else
					echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.asc] https://download.docker.com/linux/$BASE_ID $BASE_SUITE stable" \
					| tee /etc/apt/sources.list.d/docker.list > /dev/null
				fi
				{
					install -d -m 0755 /usr/share/keyrings
					wget -qO /usr/share/keyrings/docker.asc https://download.docker.com/linux/$BASE_ID/gpg
					chmod a+r /usr/share/keyrings/docker.asc
					$PM_COMMAND update
					DOCKER_PACKAGES="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
				} &>> "$LOG_FILE"
			fi
            ;;
        rhel|fedora|centos)
			if wget -q --spider https://download.docker.com/linux/$BASE_ID/ >/dev/null 2>&1; then
				DOCKER_REPO_AVAILABLE=true
				[[ -f /etc/yum.repos.d/docker-ce.repo ]] && rm -f /etc/yum.repos.d/docker-ce.repo >/dev/null 2>&1
				if [[ "$reInstallDocker" =~ ^[Yy]$ ]]; then
					REMOVE_DOCKER_PACKAGES="docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine podman runc"
				fi
				if [[ "$PM_COMMAND" == "yum" ]]; then
					{
						$PM_COMMAND "${PM_INSTALL[@]}" yum-utils
						yum-config-manager --add-repo https://download.docker.com/linux/$BASE_ID/docker-ce.repo
					} &>> "$LOG_FILE"
				elif [[ "$PM_COMMAND" == "dnf" ]]; then
					{
						$PM_COMMAND "${PM_INSTALL[@]}" dnf-plugins-core
						$PM_COMMAND config-manager --add-repo https://download.docker.com/linux/$BASE_ID/docker-ce.repo
					} &>> "$LOG_FILE"
				fi
				DOCKER_PACKAGES="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
			fi
            ;;
        *) ;;
    esac

	if [[ ! $DOCKER_REPO_AVAILABLE ]]; then
		if [[ "$DOCKER_IS_INSTALLED" ]]; then
			echo "Automatic Docker re-installation is not supported on your system at this time. After setup completes, please investigate using your current Docker installation with AMP, and if necessary re-installing Docker manually from the official Docker sources. See https://docs.docker.com/engine/install/ for more information. If you re-install Docker manually, also ensure that the '$AMP_SYS_USER' user is in the 'docker' group."
			echo "Continuing without re-installing Docker..."
			{
				usermod -a -G docker $AMP_SYS_USER
				systemctl enable docker
				systemctl start docker
			} &>> "$LOG_FILE"
			return
		else
			echo "Automatic Docker installation is not supported on your system at this time. Please investigate installing it manually after setup completes. See https://docs.docker.com/engine/install/ for more information. If you install Docker manually, also ensure that the '$AMP_SYS_USER' user is added to the 'docker' group."
			echo "Continuing without installing Docker..."
			PROVISIONFLAGS="${PROVISIONFLAGS/ +ADSModule.Defaults.UseDocker True/}"
			return
		fi
	else
		{
			if [[ "$reInstallDocker" =~ ^[Yy]$ ]] && [[ -n "$REMOVE_DOCKER_PACKAGES" ]]; then
				docker ps -q | xargs -r docker stop
				systemctl stop docker
				for pkg in $REMOVE_DOCKER_PACKAGES; do $PM_COMMAND "${PM_UNINSTALL[@]}" $pkg; done
			fi
			$PM_COMMAND "${PM_INSTALL[@]}" $DOCKER_PACKAGES
			systemctl enable docker
			systemctl start docker
			usermod -a -G docker $AMP_SYS_USER
		} &>> "$LOG_FILE"
	fi
}

function install32BitDeps {
	echo "Installing 32-bit libraries for SteamCMD applications..."
	if [ "$APT_IS_PRESENT" ]; then
		dpkg --add-architecture i386 &>> "$LOG_FILE"
		apt-get update &>> "$LOG_FILE"
	fi

# shellcheck disable=SC2086
	$PM_COMMAND "${PM_INSTALL[@]}" $LIB32_PACKAGES &>> "$LOG_FILE"
}

function installSrcdsDeps {
	install32BitDeps
}

function installNginx {
	echo "Installing nginx and certbot..."
			
	if [ "$APT_IS_PRESENT" ] && [ "$ID" == "ubuntu" ] ; then
		add-apt-repository --yes universe
		apt-get update
	fi

	$PM_COMMAND "${PM_INSTALL[@]}" certbot $CERTBOT_PACKAGE &>> "$LOG_FILE"
	
	CERTBOT_IS_PRESENT=$(isPresent certbot)
	if ! [ "$CERTBOT_IS_PRESENT" ]; then
		wget -P /usr/local/bin https://dl.eff.org/certbot-auto &>> "$LOG_FILE"
		chmod +x /usr/local/bin/certbot-auto
	fi

	$PM_COMMAND "${PM_INSTALL[@]}" nginx &>> "$LOG_FILE"
	systemctl enable nginx &>> "$LOG_FILE"
	PROVISIONFLAGS="$PROVISIONFLAGS +Core.Webserver.UsingReverseProxy True"

	if [ "$SELINUX_IS_INSTALLED" ]; then
		echo "Updating SELinux rules (httpd relay)..."
		setsebool -P httpd_can_network_relay 1
		setsebool -P httpd_can_network_connect 1
	fi
}

function installDependencies {
	echo Installing prerequisites...

	if [ "$YUM_IS_PRESENT" ]; then
		$PM_COMMAND install -y epel-release &>> "$LOG_FILE"
		yum repolist &>> "$LOG_FILE"
	fi

# shellcheck disable=SC2086
	$PM_COMMAND "${PM_INSTALL[@]}" $PREREQ_PACKAGES &>> "$LOG_FILE"

	JQ_IS_PRESENT="$(isPresent jq)"

	if [[ "$installDocker" =~ ^[Yy]$ ]]; then
		installDocker
		PROVISIONFLAGS="$PROVISIONFLAGS +ADSModule.Defaults.UseDocker True"
	fi

	if [[ "$installJava" =~ ^[Yy]$ ]]; then
		installJava
	fi

	if [[ "$install32BitLibs" =~ ^[Yy]$ ]]; then
		install32BitDeps
	fi

	if [[ "$installDarkMagic" =~ ^[Yy]$ ]]; then
		configureDarkMagicNew
	fi

	if [ -n "$SKIP_INSTALL" ]; then
		setupnginx=n;
		return
	fi	

	if [[ "$setupnginx" =~ ^[Yy]$ ]]; then
		installNginx
	fi
}

function checkConfig {
	if [[ "$setupnginx" =~ ^[Yy]$ ]] && [[ -n "$SKIPDOMAINCHECK" ]]; then
		echo -n "Checking settings... "
		domainip=$(dig "$DNS_SERVER" +short "$nginxdomain" | tail -1)

		if [ "$domainip" != "$EXTERNAL_IP" ]; then
			echo "Bad domain configuration."
			if [ -z "$domainip" ]; then
				echo "The specified domain $nginxdomain could not be resolved."
				echo "If you've only recently created the domain or record"
			else
				echo "The specified domain $nginxdomain resolves to '$domainip' but your external IP is '$EXTERNAL_IP'."
				echo "If you've recently changed the IP address this domain resolves to"
			fi
			echo "you may need to empty your DNS cache or wait for DNS propagation to complete."
			echo "Aborting setup. You can re-run this setup to try again."

			exit 100
		else
			echo "Domain $nginxdomain resolves correctly to $domainip."
		fi
	fi
} 

function addRepo {
	IFS='|' read -r BASE_ID BASE_SUITE BASE_VERSION_ID < <(mapUpstream)

	if [[ "$APT_IS_PRESENT" ]]; then
		echo "Adding CubeCoders DEB repository..."
		[[ -f /etc/apt/sources.list.d/repo.cubecoders.com.list ]] && rm -f /etc/apt/sources.list.d/repo.cubecoders.com.list >/dev/null 2>&1
		if { [[ "$BASE_ID" == "ubuntu" ]] && version_ge "$BASE_VERSION_ID" "22.04"; } || { [[ "$BASE_ID" == "debian" ]] && version_ge "$BASE_VERSION_ID" "12"; }; then
			[[ -f /etc/apt/sources.list.d/cdn-repo.c7rs.com.list ]] && rm -f /etc/apt/sources.list.d/cdn-repo.c7rs.com.list >/dev/null 2>&1
			printf "Types: deb\nURIs: https://cdn-repo.c7rs.com/%s\nSuites: debian\nComponents: \nArchitectures: %s\nSigned-By: /usr/share/keyrings/cdn-repo.c7rs.com.gpg\n" "$reposuffix" "$(dpkg --print-architecture)" \
			| tee /etc/apt/sources.list.d/cdn-repo.c7rs.com.sources > /dev/null
		else
			echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/cdn-repo.c7rs.com.gpg] https://cdn-repo.c7rs.com/$reposuffix debian/" \
			| tee /etc/apt/sources.list.d/cdn-repo.c7rs.com.list > /dev/null
		fi
		{ 
			install -d -m 0755 /usr/share/keyrings
			wget -O /usr/share/keyrings/cdn-repo.c7rs.com.gpg https://cdn-repo.c7rs.com/archive.key
			$PM_COMMAND update 
		} &>> "$LOG_FILE"
	elif [[ "$YUM_IS_PRESENT" ]]; then
		echo "Adding CubeCoders RPM repository..."
		#{
		#$PM_COMMAND "${PM_INSTALL[@]}" yum-utils
		#yum-config-manager --add-repo "https://cdn-repo.c7rs.com/${reposuffix}CubeCoders.repo"
		#} &>> "$LOG_FILE"
		# Workaround for broken repo file on aarch64
		$PM_COMMAND "${PM_INSTALL[@]}" yum-utils &>> "$LOG_FILE"
		{
			cat <<EOF
[CubeCoders]
name=CubeCoders Limited
baseurl=https://cdn-repo.c7rs.com/${reposuffix}
enabled=1
gpgcheck=0
EOF
		} > ./CubeCoders.repo 2>>"$LOG_FILE"
		yum-config-manager --add-repo ./CubeCoders.repo &>> "$LOG_FILE"
		rm ./CubeCoders.repo > /dev/null
	fi
}

function updateRepo {
	addRepo
}

function installAMP {
	echo "Installing instance manager..."
	
	if [ "$APT_IS_PRESENT" ] || [ "$YUM_IS_PRESENT" ] ; then
		echo " - Installing via package manager..."
		if ! $PM_COMMAND "${PM_INSTALL[@]}" ampinstmgr &>> "$LOG_FILE"; then
			echo "Failed to install instance manager. Aborting..."
			prnt "Possible causes for this are an unsupported distribution, or the repository being in the middle of a sync. In which case wait 30 minutes and try again, re-running the same installation command."
			
			promptLogUpload

			exit 12
		fi
	elif [ "$PACMAN_IS_PRESENT" ]; then
		echo " - Installing from tgz archive..."
		wget -q https://repo.cubecoders.com/ampinstmgr-latest.tgz &>> "$LOG_FILE"
		tar -xf ampinstmgr-latest.tgz -C / &>> "$LOG_FILE"
		rm ampinstmgr-latest.tgz
	fi
}

function addFirewallRule {
	echo "Adding firewall rule for port $1 ($2) via $FIREWALL..."
	case "$FIREWALL" in
		none) echo "No firewall installed, please add port $1 manually to your inbound firewall" ;;
		ufw) ufw allow from any to any port "$1" proto tcp comment "$2" ;;
		firewalld) firewall-cmd "--add-port=$1/tcp" --permanent && firewall-cmd --reload ;;
		iptables) iptables -A INPUT -p tcp -m tcp --dport "$1" -j ACCEPT -m comment --comment "$2" && iptables-save > /etc/iptables/rules.v4 ;;
		nft) nft add rule filter input tcp dport "$1" accept comment "\"$2\"" ;;
		*) echo "Unsupported Firewall!" ;;
	esac
}

function updateFirewall {
	echo Adding firewall rules...
	if [[ "$setupnginx" =~ ^[Yy]$ ]]; then
		addFirewallRule 443 'AMP Reverse Proxy'
		addFirewallRule 80 'AMP Reverse Proxy'
	else
		addFirewallRule "$AMP_ADS_PORT" 'AMP Management Instance'
	fi
}

function configureNginx {
	echo "{\"status\":200}" > $STATUS_FILE
	
	if ! ampinstmgr setupnginx "$nginxdomain" "$AMP_ADS_PORT" "$nginxemail"; then
		echo "Failed to configure nginx. Please check $LOG_FILE . Aborting..."
		
		promptLogUpload

		exit 19
	fi
}

function createDefaultInstance {
	if [ -n "$SKIP_INSTALL" ]; then
		return
	fi

	if [[ "$setupnginx" =~ ^[Yy]$ ]]; then
		configureNginx
	fi

	echo "Creating default instance..."
	
	if su -l $AMP_SYS_USER -c "EXTERNAL_IP=$EXTERNAL_IP INTERNAL_IP=$INTERNAL_IP EXT_HOSTNAME=$nginxdomain ampinstmgr quick $ampuser \"$amppass\" $AMP_ADS_IP $AMP_ADS_PORT $PROVISIONFLAGS"; then
		systemctl enable ampinstmgr.service
		systemctl enable ampfirewall.service
		systemctl enable ampfirewall.timer
		systemctl enable amptasks.service
		systemctl enable amptasks.timer
		systemctl start ampfirewall.timer
		systemctl start amptasks.timer
	else
		echo "Failed to create default instance."

		if [[ "$setupnginx" =~ ^[Yy]$ ]]; then
			echo "Removing generated nginx config..."
			rm "/etc/nginx/conf.d/$nginxdomain.conf" &>> "$LOG_FILE"
		fi

		echo "Aborting..."

		promptLogUpload

		exit 110
	fi
}

function checkPortAvailable {
	local lines
	lines=$($NS_COMMAND -lnt | grep -c "$AMP_ADS_PORT")
	return "$lines"
}

function getNextFreePort {
	while ! checkPortAvailable; do
		AMP_ADS_PORT=$((AMP_ADS_PORT+1))
	done
}

function postSetupHTTPS {
	if ! [ "$AMPINSTMGR_IS_INSTALLED" ]; then
		echo "AMP is not yet installed on this system. Aborting..."
		exit
	fi

	promptForHTTPS
	if [[ "$setupnginx" =~ ^[Yy]$ ]]; then
		checkConfig
		existingInstance=$(su -l $AMP_SYS_USER -c "ampinstmgr status" | grep "ADS" | cut -f 1 -d ' ')
		existingPort=$(su -l $AMP_SYS_USER -c "ampinstmgr status" | grep "ADS" | grep -E -o "[0-9]{4,5}")
		echo "AMP instance $existingInstance is currently running on port $existingPort."
		su -l $AMP_SYS_USER -c "echo ampinstmgr stop ${existingInstance}"
		su -l $AMP_SYS_USER -c "echo ampinstmgr rebind ${existingInstance} 127.0.0.1 ${existingPort}"
		su -l $AMP_SYS_USER -c "echo ampinstmgr reconfigure ${existingInstance} +Core.Webserver.UsingReverseProxy True +ADSModule.Defaults.DefaultAuthServerURL 'http://localhost:$existingPort/'"
		su -l $AMP_SYS_USER -c "echo ampinstmgr reconfiguremultiple \* +Core.Login.AuthServerURL 'http://localhost:${existingPort}/'"
		installNginx
		updateFirewall
		configureNginx
		su -l $AMP_SYS_USER -c "ampinstmgr start $existingInstance"
		cleanup
		echo "Done!"
	fi
}

function update {
	echo "Applying AMP updates..."

	if [ "$APT_IS_PRESENT" ] || [ "$YUM_IS_PRESENT" ] ; then
		$PM_COMMAND update
		$PM_COMMAND "${PM_INSTALL[@]}" ampinstmgr
	elif [ "$PACMAN_IS_PRESENT" ]; then
		installAMP
	fi

    install -d -m 0700 -o $AMP_SYS_USER -g $AMP_SYS_USER "/run/user/$(id -u $AMP_SYS_USER)"
    if ! grep -q "export XDG_RUNTIME_DIR=\"/run/user/$(id -u $AMP_SYS_USER)\"" "/home/$AMP_SYS_USER/.profile"; then
        echo "export XDG_RUNTIME_DIR=\"/run/user/$(id -u $AMP_SYS_USER)\"" >> "/home/$AMP_SYS_USER/.profile"
    fi

	echo "Updating AMP instances..."
	su -l $AMP_SYS_USER -c "ampinstmgr upgradeall"

	echo "Done!"
}

function cleanup {
	rm -f $STATUS_FILE 2> /dev/null
}

function promptLogUpload {
	if ! [ "$JQ_IS_PRESENT" ]; then
		echo "Something went wrong during the installation. GetAMP has saved an installation log at:"
		echo "$LOG_FILE"
		prnt "The log file may contain sensitive information such as username, any supplied domain names or your systems hostname so if in doubt - check the file manually before sharing it."
		return
	fi

	echo
	echo "Something went wrong during the installation. Would you like to upload your setup log for easy sharing?"
	echo "This will upload $LOG_FILE to the hastebin service and give you a URL you can share."
	echo
	prnt "The log file may contain sensitive information such as username, any supplied domain names or your systems hostname so if in doubt - check the file manually and upload it yourself."
	read -rp "[y/N] " uploadlog
	uploadlog=${uploadlog:-n}

	if [[ "$uploadlog" =~ ^[Yy]$ ]]; then
		RESPONSE=$(curl -s -X POST -F "content=<${LOG_FILE}" https://dpaste.org/api/)
		URL=$(echo $RESPONSE | grep -o 'https://dpaste.org/[a-zA-Z0-9]*')
		if [ -z "$url" ]; then
			echo "Failed to upload log file. Please check $LOG_FILE manually."
		else
			echo "Log file uploaded successfully. You can view it at:"
			urlLink "$URL"
		fi
	fi
}

function paste {
	if ! [ "$JQ_IS_PRESENT" ]; then
		echo "'jq' isn't present. Unable to paste.'"
		return
	fi

	input=$(cat)
	echo "$input"
	PASTE_KEY=$(curl -H "content-type: text/plain" -X POST https://www.toptal.com/developers/hastebin/documents --data-binary "$input" 2> /dev/null | jq -r .key 2> /dev/null)
	if [ -z "$PASTE_KEY" ]; then
		echo "Failed to upload output."
	else
		URL="https://hastebin.com/$PASTE_KEY"
		echo "Output uploaded successfully. You can view it at:"
		urlLink "$URL"
	fi
}

function debian13upgrade {
	if [ "$ID" != "debian" ] || [ "$VERSION_ID" != "13" ]; then
		echo "This function is only for use after upgrading the system from Debian 12 to 13."
		exit 1
	fi
	echo "Updating repositories for Debian 13..."
	updateRepo

	if [ -f /usr/share/keyrings/adoptium.gpg ]; then
		echo "Re-adding Adoptium repo"
		echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $VERSION_CODENAME main" | tee /etc/apt/sources.list.d/adoptium.list
	fi

	echo "Updating packages for Debian 13..."
	updateSystem
	apt install -y libicu76

	#check if i386 arch has been added previously via dpkg --add-architecture
	if dpkg --print-foreign-architectures | grep -q i386; then
		apt install -y libncurses6:i386 libtinfo6:i386
	fi
}

function uninstall_notyettested {
	clear
	echo "UNTESTED CODE - COULD CAUSE TOTAL SYSTEM DATA DESTRUCTION - BACKUP FIRST!"
	echo
	echo
	echo "-- ${BoldText}PERMANENT DATA DESTRUCTION${NormalText} --"
	echo
	echo
	prnt "Uninstalling AMP will permanently and irreversibly destroy all applications managed by AMP on this system, with no way to restore that data."
	echo
	echo "Some components such as Java, Docker and other 3rd party tools will not be removed."
	echo
	echo "Press CTRL+C to cancel."
	echo
	
	#Prompt for confirmation
	current_day=$(date -u +%A)
	phrase="I want to destroy all AMP data and the servers it manages. Today is ${current_day}."
	falsePhrase=${phrase// / }
	echo "Enter the following phrase to continue (You must type it, do not copy paste):"
	echo "${BoldText}${falsePhrase}${NormalText}"
	echo
	read -rp "Enter phrase: " userphrase
	echo

	if [[ "${userphrase}" == "${falsePhrase}" ]]; then
		echo "You copied and pasted the phrase. You must actually type it out."
		exit 1
	fi

	if [[ "${phrase}" != "${userphrase}" ]]; then
		echo "Bad confirmation. Please pay attention to case-sensitivity and punctuation."
		exit 1
	fi

	echo "Uninstalling AMP... No going back now!"
	{
	#Stop all instances
	su -l $AMP_SYS_USER -c "ampinstmgr stopall"
	killall -u $AMP_SYS_USER
	#Remove package
	$PM_COMMAND "${PM_UNINSTALL[@]}" ampinstmgr
	#Manually clean up /opt/cubecoders/amp
	rm -rf /opt/cubecoders/amp 2> /dev/null
	#Remove repositories
	rm /etc/apt/sources.list.d/repo.cubecoders.com.list 2> /dev/null
	rm /usr/share/keyrings/repo.cubecoders.com.gpg 2> /dev/null
	rm "/etc/yum.repos.d/${reposuffix}CubeCoders.repo" 2> /dev/null
	#Delete the AMP user and its home directory
	userdel -r $AMP_SYS_USER
	rm -rf "/home/${AMP_SYS_USER:?}"
	} &>> "$LOG_FILE"
	echo "Done!"
}

execute_func=""

for arg in "$@"; do
	case $arg in
		--private) PRIVATE=1 ;;
		--no-domain-verify) SKIPDOMAINCHECK=1 ;;
		--no-locale-verify) SKIPLOCALECHECK=1 ;;
		*)
			if ! type "$arg" &> /dev/null; then
				echo "No such function or flag: $arg"
				exit 1
			fi

			if [ -n "$execute_func" ]; then
				echo "Error: Multiple functions specified."
				exit 1
			fi

			execute_func="$arg"
			;;
	esac
done

if [ -n "$execute_func" ]; then
	$execute_func
	echo "Done"
	exit 0
fi


# ENTRY POINT
getNextFreePort
showWelcome

if [ "$AMP_USER_EXISTS" -eq "0" ]; then promptForSystemUser; fi

promptForAMPUser  
promptForDeps
promptForHTTPS

echo
echo "Installation Summary:" | tee $INSTALL_SUMMARY
echo | tee -a $INSTALL_SUMMARY
echo -en "AMP System user:\t\t" | tee -a $INSTALL_SUMMARY
if [ "$AMP_USER_EXISTS" -eq "0" ]; then echo "To be created"; else echo "Already exists"; fi | tee -a $INSTALL_SUMMARY
echo -en "Instance Manager:\t\t"| tee -a $INSTALL_SUMMARY
if [ "$AMPINSTMGR_IS_INSTALLED" ]; then echo "Already installed"; else echo "To be installed"; fi| tee -a $INSTALL_SUMMARY
echo -en "HTTPS setup:\t\t\t"| tee -a $INSTALL_SUMMARY
if [[ "$setupnginx" =~ ^[Yy]$ ]]; then echo "Yes, via nginx with domain $nginxdomain"; else echo "No"; fi| tee -a $INSTALL_SUMMARY
noReason=$( [[ "$installDocker" =~ ^[Yy]$ ]] && echo "Not required (replying on Docker)" || echo "No" )
echo -en "Install Docker:\t\t\t" | tee -a $INSTALL_SUMMARY
if [[ "$installDocker" =~ ^[Yy]$ ]]; then echo "Yes"; else echo "No"; fi | tee -a $INSTALL_SUMMARY
if [ "$ARCH" == "x86_64" ]; then
	echo -en "Install 32-bit libraries:\t" | tee -a $INSTALL_SUMMARY
	if [[ "$install32BitLibs" =~ ^[Yy]$ ]]; then echo "Yes"; else echo "$noReason"; fi | tee -a $INSTALL_SUMMARY
fi
echo -en "Install Java:\t\t\t"| tee -a $INSTALL_SUMMARY
if [[ "$installJava" =~ ^[Yy]$ ]]; then echo "Yes"; else echo "$noReason"; fi | tee -a $INSTALL_SUMMARY
if [ "$ARCH" == "aarch64" ]; then
	echo -en "Configure CPx2:\t\t\t" | tee -a $INSTALL_SUMMARY
	if [[ "$installDarkMagic" =~ ^[Yy]$ ]]; then echo "Yes"; else echo "No"; fi | tee -a $INSTALL_SUMMARY
fi

if [ -z "$USE_ANSWERS" ]; then
	echo 
	echo "Ready to install AMP. Press ENTER to continue or CTRL+C to cancel."
	read -r
	echo
fi

echo Installing AMP...

if [ "$AMP_USER_EXISTS" -eq "0" ]; then
	createUser
else
	echo "$AMP_SYS_USER already exists. Skipping..."

	if [ "$AMPINSTMGR_IS_INSTALLED" ]; then
		if [ "$(su -l $AMP_SYS_USER -c 'ampinstmgr status | grep -c "│"')" -gt 1 ]; then
			echo "$AMP_SYS_USER already has instances. AMP appears to be already installed and configured. Aborting..."
			exit 135
		fi
	fi
fi

updateSystem
installDependencies
checkConfig

if ! [ "$AMPINSTMGR_IS_INSTALLED" ]; then
	addRepo
	installAMP
else
	echo "AMP instance manager already installed. Skipping..."
fi

updateFirewall
createDefaultInstance
cleanup

echo
echo "Installation complete. Thanks for using AMP!"
echo

if [[ "$setupnginx" =~ ^[Yy]$ ]]; then
	echo "You can now reach AMP at $(urlLink "https://$nginxdomain/")"
	echo
	echo "https://$nginxdomain/" | qrencode -t UTF8 -m 2 | sed -e "6s|$|	Scan this code or visit $(urlLink "https://$nginxdomain/")|" -e "7s|$|	to start using AMP from your mobile device.|"
	echo
elif [ "$INTERNAL_IP" == "$EXTERNAL_IP" ]; then
	echo "You can now reach AMP at $(urlLink "http://$INTERNAL_IP:$AMP_ADS_PORT/")"
	echo
	echo "http://$INTERNAL_IP:$AMP_ADS_PORT/" | qrencode -t UTF8 -m 2 | sed -e "6s|$|	Scan this code or visit $(urlLink "http://$INTERNAL_IP:$AMP_ADS_PORT/")|" -e "7s|$|	to start using AMP from your mobile device.|"
	echo
else
	echo "You can now reach AMP at $(urlLink "http://$INTERNAL_IP:$AMP_ADS_PORT/")"
	echo "or at $(urlLink "http://$EXTERNAL_IP:$AMP_ADS_PORT/")"
	echo
	echo "http://$INTERNAL_IP:$AMP_ADS_PORT/" | qrencode -t UTF8 -m 2 | sed -e "6s|$|	Scan this code or visit $(urlLink "http://$INTERNAL_IP:$AMP_ADS_PORT/")|" -e "7s|$|	to start using AMP from your mobile device.|" -e "8s|$|	(You must be connected to the same network as the server)|"
	echo
fi
