#!/bin/bash
# =================== YOUR DATA ========================
#bash <( curl -s https://raw.githubusercontent.com/trustake-co-uk/server/master/install-server.sh )

SERVER_IP=$(curl --silent whatismyip.akamai.com)
# =================== YOUR DATA ========================
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}* Sorry, this script needs to be run as root. Do \"sudo su root\" and then re-run this script${NONE}"
    exit 1
    echo -e "${NONE}${GREEN}* All Good!${NONE}";
fi
clear
echo -e "${UNDERLINE}${BOLD}Coldstake.co.in Server & Node Installation Guide${NONE}"
echo
read -p "Which Fork (pivx)? " fork
read -p "What sub-domain (default=${fork})? " subdomain
read -p "Mainnet (m) or Testnet (t)? " net
read -p "Which branch (default=master)? " branch
echo "Add your SSH public key here: "
read -p "" PUBLIC_SSH_KEYS

if [[ ${subdomain} == '' ]]; then 
    subdomain="${fork}"
fi

if [[ ${branch} == '' ]]; then 
    branch="master"
fi

# =================== YOUR DATA ========================
SERVER_NAME="${subdomain}.coldstake.co.in"
REDIRECTURL="https:\/\/${SERVER_NAME}\/activate.php"
IPNURL="https:\/\/${SERVER_NAME}\/IPNlogger.php"
DNS_NAME="${subdomain}.coldstake.co.in"
USER="$fork-web"
COINSERVICEINSTALLER="https://raw.githubusercontent.com/trustake-co-uk/server/master/install-coin.sh )"
COINSERVICECONFIG="https://raw.githubusercontent.com/trustake-co-uk/server/master/config/config-$fork.sh"
WEBFILE="https://github.com/trustake-co-uk/node.git"

#TODO: Replace with config files

if [[ "$net" =~ ^([tT])+$ ]]; then
    case $fork in ##### TESTNET
         pivx)
            port="51474";
            payment="1";
            ;;
         *)
           echo "$fork has not been configured."
           exit
           ;;
    esac
else 
    case $fork in ##### MAINNET
        pivx)
            port="51472";
            payment="1";
            ;;
         *)
            echo "$fork has not been configured."
            exit
            ;;
    esac
fi

# =================== YOUR DATA ========================
read -p "Are you using DNS(y) or IP(n)?" dns

if [[ "$dns" =~ ^([nN])+$ ]]; then
    DNS_NAME=${SERVER_IP}
    else
    read -p "Before you continue ensure that your DNS has an 'A' record for ${SERVER_IP} - press any key to continue" response
fi

# SSH access via password will be disabled. Use keys instead.
###### add manually for aruba
PUBLIC_SSH_KEYS=""

# if vps not contains swap file - create it
SWAP_SIZE="1G"

TIMEZONE="Etc/GMT+0" # list of avaiable timezones: ls -R --group-directories-first /usr/share/zoneinfo

# =================== AUTOMATION ================

# Prefer IPv4 over IPv6 - make apt-get faster

sudo sed -i "s/#precedence ::ffff:0:0\/96  100/precedence ::ffff:0:0\/96  100/" /etc/gai.conf

# Upgrade The Base Packages

apt update -qy
apt upgrade -qy

# Add A Few PPAs To Stay Current

apt -qy install software-properties-common

apt-add-repository ppa:nginx/development -y
apt-add-repository ppa:ondrej/nginx -y
apt-add-repository ppa:ondrej/php -y
apt-add-repository ppa:certbot/certbot -y

# Update Package Lists

apt update -qy

# Base Packages

apt-get install -qy build-essential curl fail2ban \
gcc git libmcrypt4 libpcre3-dev python-certbot-nginx \
make python2.7 python-pip supervisor ufw unattended-upgrades \
unzip whois zsh mc p7zip-full htop

# Disable Password Authentication Over SSH & switch default port

sed -ri 's/#Port 22/Port 7777/g' /etc/ssh/sshd_config
sed -ri 's/X11Forwarding yes/X11Forwarding no/g' /etc/ssh/sshd_config
sed -ri 's/#AllowTcpForwarding yes/AllowTcpForwarding no/g' /etc/ssh/sshd_config
sed -ri 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -ri 's/#UsePAM yes/UsePAM no/g' /etc/ssh/sshd_config
sed -ri 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/g' /etc/ssh/sshd_config
echo 'PermitRootLogin no' &>> /etc/ssh/sshd_config

ufw allow 7777 ## check vps provider has port 7777 open

# Restart SSH

ssh-keygen -A
service ssh restart

# Set The Hostname If Necessary

echo "${SERVER_NAME}" > /etc/hostname
sed -i "s/127\.0\.0\.1.*localhost/127.0.0.1	${SERVER_NAME} localhost/" /etc/hosts
hostname ${SERVER_NAME}

# Set The Timezone

ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
update-locale LANG="en_US.UTF-8"

# Create The Root SSH Directory If Necessary

if [ ! -d /root/.ssh ]
then
    mkdir -p /root/.ssh
    touch /root/.ssh/authorized_keys
fi

# Setup User

useradd $USER
mkdir -p /home/$USER/.ssh
adduser $USER sudo

# Setup Bash For User

chsh -s /bin/bash $USER
cp /root/.profile /home/$USER/.profile
cp /root/.bashrc /home/$USER/.bashrc

# Remove Sudo Password For User
echo "${USER} ALL=(ALL) NOPASSWD: ALL" &>> /etc/sudoers

# Build Formatted Keys & Copy Keys To User

cat > /root/.ssh/authorized_keys << EOF
$PUBLIC_SSH_KEYS
EOF

cp /root/.ssh/authorized_keys /home/$USER/.ssh/authorized_keys

# Create The Server SSH Key

ssh-keygen -f /home/$USER/.ssh/id_rsa -t rsa -N ''

# Copy Github And Bitbucket Public Keys Into Known Hosts File

ssh-keyscan -H github.com >> /home/$USER/.ssh/known_hosts
ssh-keyscan -H bitbucket.org >> /home/$USER/.ssh/known_hosts

# Setup Site Directory Permissions

chown -R $USER:$USER /home/$USER
chmod -R 755 /home/$USER
chmod 700 /home/$USER/.ssh/id_rsa

# Setup Unattended Security Upgrades

cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "Ubuntu xenial-security";
};
Unattended-Upgrade::Package-Blacklist {
    //
};
EOF

cat > /etc/apt/apt.conf.d/10periodic << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Setup UFW Firewall

ufw allow 22
ufw allow 'Nginx Full'
ufw --force enable

# Allow FPM Restart

echo "$USER ALL=NOPASSWD: /usr/sbin/service php7.4-fpm reload" > /etc/sudoers.d/php-fpm

# Configure Supervisor Autostart

systemctl enable supervisor.service
service supervisor start

# Configure Swap Disk

if [ -f /swap.img ]; then
    echo "Swap exists."
else
    fallocate -l $SWAP_SIZE /swap.img
    chmod 600 /swap.img
    mkswap /swap.img
    swapon /swap.img
    echo "/swap.img none swap sw 0 0" >> /etc/fstab
    echo "vm.swappiness=30" >> /etc/sysctl.conf
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
fi

# Install Base PHP Packages

sudo apt -qy install php7.4-fpm php7.4-common php7.4-mysql php7.4-xml \
php7.4-xmlrpc php7.4-curl php7.4-gd libpcre2-dev \
php-imagick php7.4-cli php7.4-dev php7.4-imap php7.4-mbstring \
php7.4-sqlite3 php-memcached php7.1-mcrypt php7.4-bcmath php7.4-intl php7.4-readline \
php7.4-opcache php7.4-soap php7.4-zip unzip php7.4-pgsql php-msgpack \
gcc make re2c libpcre3-dev software-properties-common build-essential 

# Misc. PHP CLI Configuration

sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.4/cli/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.4/cli/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.4/cli/php.ini
sudo sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.4/cli/php.ini

# Configure Sessions Directory Permissions

chmod 733 /var/lib/php/sessions
chmod +t /var/lib/php/sessions

# Install Nginx & PHP-FPM

apt install -qy nginx php7.4-fpm

# Enable Nginx service
systemctl enable nginx.service

# Generate dhparam File

openssl dhparam -out /etc/nginx/dhparams.pem 2048

# Disable The Default Nginx Site

rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default
service nginx restart

# Tweak Some PHP-FPM Settings

sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.4/fpm/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.4/fpm/php.ini
sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.4/fpm/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.4/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.4/fpm/php.ini
sed -i "s/short_open_tag.*/short_open_tag = On/" /etc/php/7.4/fpm/php.ini

# Setup Session Save Path

sed -i "s/\;session.save_path = .*/session.save_path = \"\/var\/lib\/php5\/sessions\"/" /etc/php/7.4/fpm/php.ini
sed -i "s/php5\/sessions/php\/sessions/" /etc/php/7.4/fpm/php.ini

# Configure Nginx & PHP-FPM To Run As User

sed -i "s/user www-data;/user $USER;/" /etc/nginx/nginx.conf
sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf
sed -i "s/^user = www-data/user = $USER/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/^group = www-data/group = $USER/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/;listen\.owner.*/listen.owner = $USER/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/;listen\.group.*/listen.group = $USER/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php/7.4/fpm/pool.d/www.conf

# Configure A Few More Server Things

sed -i "s/;request_terminate_timeout.*/request_terminate_timeout = 60/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/worker_processes.*/worker_processes auto;/" /etc/nginx/nginx.conf
sed -i "s/# multi_accept.*/multi_accept on;/" /etc/nginx/nginx.conf

# Install A Catch All Server

cat > /etc/nginx/sites-available/catch-all << EOF
server {
    return 404;
}
EOF

ln -s /etc/nginx/sites-available/catch-all /etc/nginx/sites-enabled/catch-all

cat > /etc/nginx/sites-available/${SERVER_NAME} << EOF
server {
    listen 80;
    server_name ${DNS_NAME};
    root /home/${USER}/${SERVER_NAME}/;
    index index.html index.htm index.php;
    charset utf-8;

    location / {
        index index.php;
        try_files \$uri \$uri/ \$uri.php;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }
    access_log off;
    error_log  /var/log/nginx/${SERVER_NAME}-error.log error;
    error_page 404 /index.php;

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
        include fastcgi_params;
        fastcgi_intercept_errors on;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -s /etc/nginx/sites-available/${SERVER_NAME} /etc/nginx/sites-enabled/${SERVER_NAME}

# Restart Nginx & PHP-FPM Services
if [ ! -z "\$(ps aux | grep php-fpm | grep -v grep)" ]
then
    service php7.4-fpm restart 
fi

service nginx restart
service nginx reload

# Add User To www-data Group

usermod -a -G www-data $USER
id $USER
groups $USER

# Install Composer Package Manager

curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Install SSL certificate if using DNS

if [[ "$dns" =~ ^([yY])+$ ]]; then
certbot --nginx \
  --non-interactive \
  --agree-tos \
  --email coldstake.co.in@protonmail.com \
  --domains ${SERVER_NAME}
fi

# Install Website
mkdir /home/${USER}/${SERVER_NAME}
cd /home/${USER}/
git clone ${WEBFILE} ${SERVER_NAME}
chown ${USER}:www-data /home/${USER}/${SERVER_NAME} -R
chmod g+rw /home/${USER}/${SERVER_NAME} -R
chmod g+s /home/${USER}/${SERVER_NAME} -R
cd /home/${USER}/${SERVER_NAME}
#php /usr/local/bin/composer btcpayserver/btcpayserver-php-client
php /usr/local/bin/composer require trustaking/btcpayserver-php-client:dev-master

## Inject apiport & ticker into /include/config.php
sed -i "s/^\(\$ticker='\).*/\1$fork';/" /home/${USER}/${SERVER_NAME}/include/config.php
sed -i "s/^\(\$api_port='\).*/\1$apiport';/" /home/${USER}/${SERVER_NAME}/include/config.php
sed -i "s/^\(\$redirectURL='\).*/\1${REDIRECTURL}';/" /home/${USER}/${SERVER_NAME}/include/config.php
sed -i "s/^\(\$ipnURL='\).*/\1${IPNURL}';/" /home/${USER}/${SERVER_NAME}/include/config.php
sed -i "s/^\(\$api_ver='\).*/\1${apiver}';/" /home/${USER}/${SERVER_NAME}/include/config.php
sed -i "s/^\(\$coldstakeui='\).*/\1${coldstakeui}';/" /home/${USER}/${SERVER_NAME}/include/config.php
sed -i "s/^\(\$payment='\).*/\1${payment}';/" /home/${USER}/${SERVER_NAME}/include/config.php
sed -i "s/^\(\$whitelist='\).*/\1${whitelist}';/" /home/${USER}/${SERVER_NAME}/include/config.php

#Inject RPC username & password into config.php
sed -i "s/^\(\$rpc_user='\).*/\1${RPCUSER}';/" /home/${USER}/${SERVER_NAME}/include/config.php
sed -i "s/^\(\$rpc_pass='\).*/\1${RPCPASS}';/" /home/${USER}/${SERVER_NAME}/include/config.php

# Install Coins Service
read -p "Hit a key to install Coin service!" response
wget ${COINSERVICEINSTALLER} -O ~/install-coin.sh
wget ${COINSERVICECONFIG} -O ~/config-${fork}.sh
chmod +x ~/install-coin.sh
cd ~
~/install-coin.sh -f ${fork} -n ${net} -b ${branch}

# Display information
echo
echo -e "Running a simulation for SSL renewal"
echo 
certbot renew --dry-run
echo && echo
echo "If the dry run was unsuccessful you may need to register & install your SSL certificate manually by running the following command: "
echo
echo "certbot --nginx --non-interactive --agree-tos --email admin@trustaking.com --domains ${DNS_NAME}"
echo
echo "Website URL: "${DNS_NAME}
[ ! -d /var/secure ] && mkdir -p /var/secure 
echo "Requires keys.php, btcpayserver.pri & pub in /var/secure/ - run transfer.sh"