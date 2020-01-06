#!/bin/bash
#bash <( curl -s https://raw.githubusercontent.com/trustake-co-uk/server/master/install-pivx-staking-node.sh )

NONE='\033[00m'
RED='\033[01;31m'
GREEN='\033[01;32m'
PURPLE='\033[01;35m'
BOLD='\033[1m'
UNDERLINE='\033[4m'

function setVars() {
## set network dependent variables
NODE_USER=pivx
COINCORE=/home/${NODE_USER}/{NODE_USER}/.pivx
COINPORT=51472 #51474 testnet
COINRPCPORT=51473 #51475 testnet

## set general variables
DATE_STAMP="$(date +%y-%m-%d-%s)"
OS_VER="Ubuntu*"
RPCUSER=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
RPCPASS=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
COINBIN=https://github.com/PIVX-Project/PIVX/releases/download/v4.0.0/pivx-4.0.0-x86_64-linux-gnu.tar.gz
COINDAEMON=${NODE_USER}d
COINSTARTUP=/home/${NODE_USER}/${NODE_USER}d
COINSTOP=/home/${NODE_USER}/${NODE_USER}d
COINDLOC=/home/${NODE_USER}/${NODE_USER}node/pivx-4.0.0/bin/
COINSERVICELOC=/etc/systemd/system/
COINSERVICENAME=${COINDAEMON}@${NODE_USER}
SWAPSIZE="1024" ## =1GB
SCRIPT_LOGFILE="/tmp/${NODE_USER}_${DATE_STAMP}_output.log"
COINRUNCMD="./${COINDAEMON} -daemon -datadir=${COINCORE} -rpcuser=${RPCUSER} -rpcpassword=${RPCPASS} \${stakeparams}"
COINSTOPCMD="./${NODE_USER}-cli -datadir=${COINCORE} -rpcuser=${RPCUSER} -rpcpassword=${RPCPASS} stop"
}

function check_root() {
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}* Sorry, this script needs to be run as root. Do \"sudo su root\" and then re-run this script${NONE}"
    exit 1
    echo -e "${NONE}${GREEN}* All Good!${NONE}";
fi
}

function create_user() {
    echo
    echo "* Checking for user & add if required. Please wait..."
    # our new mnode unpriv user acc is added
    if id "${NODE_USER}" >/dev/null 2>&1; then
        echo "user exists already, do nothing"
    else
        echo -e "${NONE}${GREEN}* Adding new system user ${NODE_USER}${NONE}"
        adduser --disabled-password --gecos "" ${NODE_USER}&>> ${SCRIPT_LOGFILE}
        usermod -aG sudo ${NODE_USER} &>> ${SCRIPT_LOGFILE}
        echo -e "${NODE_USER} ALL=(ALL) NOPASSWD:ALL" &>> /etc/sudoers

    fi
    echo -e "${NONE}${GREEN}* Done${NONE}";
}

function set_permissions() {
    chown -R ${NODE_USER}:${NODE_USER} ${COINCORE} ${COINSTARTUP} ${COINDLOC} &>> ${SCRIPT_LOGFILE}
    # make group permissions same as user, so vps-user can be added to node group
    chmod -R g=u ${COINCORE} ${COINSTARTUP} ${COINDLOC} ${COINSERVICELOC} &>> ${SCRIPT_LOGFILE}
}

function checkOSVersion() {
   echo
   echo "* Checking OS version..."
    if [[ `cat /etc/issue.net`  == ${OS_VER} ]]; then
        echo -e "${GREEN}* You are running `cat /etc/issue.net` . Setup will continue.${NONE}";
    else
        echo -e "${RED}* You are not running ${OS_VER}. You are running `cat /etc/issue.net` ${NONE}";
        echo && echo "Installation cancelled" && echo;
        exit;
    fi
}

function updateAndUpgrade() {
    echo
    echo "* Running update and upgrade. Please wait..."
    apt-get update &>> ${SCRIPT_LOGFILE}
    DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -y -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" dist-upgrade &>> ${SCRIPT_LOGFILE}
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y &>> ${SCRIPT_LOGFILE}
    echo -e "${GREEN}* Done${NONE}";
}

function setupSwap() {
#check if swap is available
    echo
    echo "* Creating Swap File. Please wait..."
    if [ $(free | awk '/^Swap:/ {exit !$2}') ] || [ ! -f "/var/node_swap.img" ];then
    echo -e "${GREEN}* No proper swap, creating it.${NONE}";
    # needed because ant servers are ants
    rm -f /var/node_swap.img &>> ${SCRIPT_LOGFILE}
    dd if=/dev/zero of=/var/node_swap.img bs=1024k count=${SWAPSIZE} &>> ${SCRIPT_LOGFILE}
    chmod 0600 /var/node_swap.img &>> ${SCRIPT_LOGFILE}
    mkswap /var/node_swap.img &>> ${SCRIPT_LOGFILE}
    swapon /var/node_swap.img &>> ${SCRIPT_LOGFILE}
    echo '/var/node_swap.img none swap sw 0 0' | tee -a /etc/fstab &>> ${SCRIPT_LOGFILE}
    echo 'vm.swappiness=10' | tee -a /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
    echo 'vm.vfs_cache_pressure=50' | tee -a /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
else
    echo -e "${GREEN}* All good, we have a swap.${NONE}";
fi
}

function installFail2Ban() {
    echo
    echo -e "* Installing fail2ban. Please wait..."
    apt-get -y install fail2ban &>> ${SCRIPT_LOGFILE}
    systemctl enable fail2ban &>> ${SCRIPT_LOGFILE}
    systemctl start fail2ban &>> ${SCRIPT_LOGFILE}
    # Add Fail2Ban memory hack if needed
    if ! grep -q "ulimit -s 256" /etc/default/fail2ban; then
       echo "ulimit -s 256" | tee -a /etc/default/fail2ban &>> ${SCRIPT_LOGFILE}
       systemctl restart fail2ban &>> ${SCRIPT_LOGFILE}
    fi
    echo -e "${NONE}${GREEN}* Done${NONE}";
}

function installFirewall() {
    echo
    echo -e "* Installing UFW. Please wait..."
    apt-get -y install ufw &>> ${SCRIPT_LOGFILE}
    ufw allow OpenSSH &>> ${SCRIPT_LOGFILE}
    ufw allow $COINPORT/tcp &>> ${SCRIPT_LOGFILE}
    ufw allow $COINRPCPORT/tcp &>> ${SCRIPT_LOGFILE}
    if [ "${DNSPORT}" != "" ] ; then
        ufw allow ${DNSPORT}/tcp &>> ${SCRIPT_LOGFILE}
        ufw allow ${DNSPORT}/udp &>> ${SCRIPT_LOGFILE}
    fi
    echo "y" | ufw enable &>> ${SCRIPT_LOGFILE}
    echo -e "${NONE}${GREEN}* Done${NONE}";
}

function installDependencies() {
    echo
    echo -e "* Installing dependencies. Please wait..."
    timedatectl set-ntp no &>> ${SCRIPT_LOGFILE}
    ## Sufficient dependencies to compile from source if require
    apt-get install git ntp nano wget curl make gcc software-properties-common -y &>> ${SCRIPT_LOGFILE}
    add-apt-repository -yu ppa:pivx/pivx  &>> ${SCRIPT_LOGFILE}
    apt-get -o=Dpkg::Use-Pty=0 -o=Acquire::ForceIPv4=true update  &>> ${SCRIPT_LOGFILE}
    apt-get -y -o=Dpkg::Use-Pty=0 -o=Acquire::ForceIPv4=true install build-essential \
    protobuf-compiler libboost-all-dev autotools-dev automake libcurl4-openssl-dev \
    libssl-dev libgmp-dev make autoconf libtool git apt-utils g++ \
    libprotobuf-dev pkg-config libcurl3-dev libudev-dev libqrencode-dev bsdmainutils \
    pkg-config libgmp3-dev libevent-dev jp2a pv virtualenv libdb4.8-dev libdb4.8++-dev  &>> ${SCRIPT_LOGFILE}

    if [[ -r /etc/os-release ]]; then
        . /etc/os-release
        if [[ "${VERSION_ID}" = "16.04" ]]; then

            echo -e "${NONE}${GREEN}* Done${NONE}";
        fi
        if [[ "${VERSION_ID}" = "18.04" ]]; then
            apt-get -qqy -o=Dpkg::Use-Pty=0 -o=Acquire::ForceIPv4=true install libssl1.0-dev
            echo -e "${NONE}${GREEN}* Done${NONE}";
        fi
        if [[ "${VERSION_ID}" = "19.04" ]]; then
            apt-get -qqy -o=Dpkg::Use-Pty=0 -o=Acquire::ForceIPv4=true install libssl1.0-dev
            echo -e "${NONE}${GREEN}* Done${NONE}";
        fi
        else
        echo -e "${NONE}${RED}* Version: ${VERSION_ID} not supported.${NONE}";
    fi
}

function compileWallet() {
    echo
    echo -e "* Compiling wallet. Please wait, this might take a while to complete..."
    rm -rf ${COINDLOC} &>> ${SCRIPT_LOGFILE}
    mkdir -p ${COINDLOC} &>> ${SCRIPT_LOGFILE}
    cd /home/${NODE_USER}/
    wget --https-only -O coinbin.tar ${COINBIN} &>> ${SCRIPT_LOGFILE}
    tar -zxf coinbin.tar -C ${COINDLOC} &>> ${SCRIPT_LOGFILE}
    rm coinbin.tar &>> ${SCRIPT_LOGFILE}
    echo -e "${NONE}${GREEN}* Done${NONE}";
}

function installWallet() {
    echo
    echo -e "* Installing wallet. Please wait..."
    cd /home/${NODE_USER}/
    echo -e "#!/bin/bash\ncd $COINDLOC\n$COINRUNCMD" > ${COINSTARTUP}
    echo -e "#!/bin/bash\ncd $COINDLOC\n$COINSTOPCMD" > ${COINSTOP}
    echo -e "[Unit]\nDescription=${COINDAEMON}\nAfter=network-online.target\n\n[Service]\nType=simple\nUser=${NODE_USER}\nGroup=${NODE_USER}\nExecStart=${COINSTARTUP}\nExecStop=${COINSTOP}\nRestart=always\nRestartSec=5\nPrivateTmp=true\nTimeoutStopSec=60s\nTimeoutStartSec=5s\nStartLimitInterval=120s\nStartLimitBurst=15\n\n[Install]\nWantedBy=multi-user.target" >${COINSERVICENAME}.service
    chown -R ${NODE_USER}:${NODE_USER} ${COINSERVICELOC} &>> ${SCRIPT_LOGFILE}
    mv $COINSERVICENAME.service ${COINSERVICELOC} &>> ${SCRIPT_LOGFILE}
    chmod 777 ${COINSTARTUP} &>> ${SCRIPT_LOGFILE}
    systemctl --system daemon-reload &>> ${SCRIPT_LOGFILE}
    systemctl enable ${COINSERVICENAME} &>> ${SCRIPT_LOGFILE}
    echo -e "${NONE}${GREEN}* Done${NONE}";
}

function startWallet() {
    echo
    echo -e "* Starting wallet daemon...${COINSERVICENAME}"
    service ${COINSERVICENAME} start &>> ${SCRIPT_LOGFILE}
    sleep 10
    echo -e "${GREEN}* Done${NONE}";
}
function stopWallet() {
    echo
    echo -e "* Stopping wallet daemon...${COINSERVICENAME}"
    service ${COINSERVICENAME} stop &>> ${SCRIPT_LOGFILE}
    sleep 2
    echo -e "${GREEN}* Done${NONE}";
}

function installUnattendedUpgrades() {
    echo
    echo "* Installing Unattended Upgrades..."
    apt-get install unattended-upgrades -y &>> ${SCRIPT_LOGFILE}
    sleep 3
    sh -c 'echo "Unattended-Upgrade::Allowed-Origins {" >> /etc/apt/apt.conf.d/50unattended-upgrades'
    sh -c 'echo "        \"\${distro_id}:\${distro_codename}\";" >> /etc/apt/apt.conf.d/50unattended-upgrades'
    sh -c 'echo "        \"\${distro_id}:\${distro_codename}-security\";}" >> /etc/apt/apt.conf.d/50unattended-upgrades'
    sh -c 'echo "APT::Periodic::AutocleanInterval \"7\";" >> /etc/apt/apt.conf.d/20auto-upgrades'
    sh -c 'echo "APT::Periodic::Unattended-Upgrade \"1\";" >> /etc/apt/apt.conf.d/20auto-upgrades'
    cat /etc/apt/apt.conf.d/50unattended-upgrades &>> ${SCRIPT_LOGFILE}
    cat /etc/apt/apt.conf.d/20auto-upgrades &>> ${SCRIPT_LOGFILE}
    echo -e "${GREEN}* Done${NONE}";
}

function displayServiceStatus() {
	echo
	echo
	on="${GREEN}ACTIVE${NONE}"
	off="${RED}OFFLINE${NONE}"

	if systemctl is-active --quiet ${COINSERVICENAME}; then echo -e "Service: ${on}"; else echo -e "Service: ${off}"; fi
}

### Begin execution plan ####
clear
echo -e "${PURPLE}**********************************************************************${NONE}"
echo -e "${PURPLE}*  This script will install and configure your cold staking node.    *${NONE}"
echo -e "${PURPLE}**********************************************************************${NONE}"
echo -e "${BOLD}"

cd /home/${NODE_USER}/

    check_root
    setVars
    checkOSVersion
    echo
    echo -e "${BOLD} The log file can be monitored here: ${SCRIPT_LOGFILE}${NONE}"
    updateAndUpgrade
    create_user
    setupSwap
    installFail2Ban
    installFirewall
    installDependencies
    compileWallet
    installWallet
    installUnattendedUpgrades
    startWallet
    stopWallet
    startWallet
    set_permissions
    displayServiceStatus

echo
echo -e "${GREEN} Installation complete. Check service with: journalctl -f -u ${COINSERVICENAME} ${NONE}"
echo -e "${GREEN} If you find this service valuable we appreciate any tips, please visit https://donations.coldstake.co.in ${NONE}"
echo -e "${GREEN} thecrypt0hunter(2020)${NONE}"
cd ~