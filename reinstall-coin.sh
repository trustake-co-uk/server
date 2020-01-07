#!/bin/bash
# =================== Run this script ========================
#bash <( curl -s https://raw.githubusercontent.com/trustake-co-uk/server/master/reinstall-coin.sh )


# =================== Get Info ========================
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}* Sorry, this script needs to be run as root. Do \"sudo su root\" and then re-run this script${NONE}"
    exit 1
    echo -e "${NONE}${GREEN}* All Good!${NONE}";
fi
clear
echo -e "${UNDERLINE}${BOLD}Coldstaking Node Installation Guide${NONE}"
echo
read -p "Which Fork (pivx)? " fork
read -p "Mainnet (m) or Testnet (t)? " net
read -p "Which branch (default=master)? " branch

if [ "${branch}" == "" ]; then 
branch="master";
fi

# =================== YOUR DATA ========================
COINSERVICEINSTALLER="https://raw.githubusercontent.com/trustake-co-uk/server/master/install-coin.sh )"
COINSERVICECONFIG="https://raw.githubusercontent.com/trustake-co-uk/server/master/config/config-$fork.sh"

# Clear old installation
rm -rf ${fork}
rm /etc/apt/apt.conf.d/20auto-upgrades
rm /etc/apt/apt.conf.d/50unattended-upgrades
rm /etc/systemd/system/${fork}d@${fork}.service

# Install Coin Service
read -p "Hit a key to install Coin service!" response
wget ${COINSERVICEINSTALLER} -O ~/install-coin.sh
wget ${COINSERVICECONFIG} -O ~/config-${fork}.sh
chmod +x ~/install-coin.sh
cd ~
~/install-coin.sh -f ${fork} -n ${net} -b ${branch}