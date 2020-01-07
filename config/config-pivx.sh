function setMainVars() {
## set network dependent variables
NETWORK=""
NODE_USER=${FORK}${NETWORK}
COINCORE=/home/${NODE_USER}/.${NODE_USER}
COINPORT=51472 #51474 testnet
COINRPCPORT=51473 #51475 testnet
}

function setTestVars() {
## set network dependent variables
NETWORK="-testnet"
NODE_USER=${FORK}${NETWORK}
COINCORE=/home/${NODE_USER}/.${NODE_USER}
COINPORT=51474
COINRPCPORT=51475
}

function setGeneralVars() {
## set general variables
DATE_STAMP="$(date +%y-%m-%d-%s)"
OS_VER="Ubuntu*"
RPCUSER=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
RPCPASS=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
COINBIN=https://github.com/PIVX-Project/PIVX/releases/download/v4.0.0/pivx-4.0.0-x86_64-linux-gnu.tar.gz
COINDAEMON=${NODE_USER}d
COINSTARTUP=/home/${NODE_USER}/${NODE_USER}-start
COINSTOP=/home/${NODE_USER}/${NODE_USER}-stop
COININFO=/home/${NODE_USER}/${NODE_USER}-cli
COINBINDIR=/home/${NODE_USER}/${NODE_USER}node/
COINDLOC=/home/${NODE_USER}/${NODE_USER}node/pivx-4.0.0/bin/
COINSERVICELOC=/etc/systemd/system/
COINSERVICENAME=${COINDAEMON}@${NODE_USER}
SWAPSIZE="1024" ## =1GB
SCRIPT_LOGFILE="/tmp/${NODE_USER}_${DATE_STAMP}_output.log"
COINRUNCMD="./${COINDAEMON} -datadir=${COINCORE} -rpcuser=${RPCUSER} -rpcpassword=${RPCPASS}"
COINSTOPCMD="./${NODE_USER}-cli -datadir=${COINCORE} -rpcuser=${RPCUSER} -rpcpassword=${RPCPASS} stop"
COININFOCMD="./${NODE_USER}-cli -datadir=${COINCORE} -rpcuser=${RPCUSER} -rpcpassword=${RPCPASS} \$@"
}
