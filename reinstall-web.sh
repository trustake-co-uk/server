#!/bin/bash
# =================== YOUR DATA ========================
#bash <( curl -s https://raw.githubusercontent.com/trustake-co-uk/server/master/reinstall-web.sh )

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
    DNS_NAME=$(curl --silent ipinfo.io/ip)
fi

## Add site-available and enable the website
if [ ! -f /etc/nginx/sites-available/${SERVER_NAME} ]; then

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
        fastcgi_pass unix:/var/run/php/php7.3-fpm.sock;
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
    service php7.3-fpm restart
fi

service nginx restart
service nginx reload

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

fi

# Setup User
useradd $USER
mkdir -p /home/$USER/
adduser $USER sudo

# Setup Bash For User
chsh -s /bin/bash $USER
cp /root/.profile /home/$USER/.profile
cp /root/.bashrc /home/$USER/.bashrc

# Remove Sudo Password For User
echo "${USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers

# Setup Site Directory Permissions
chown -R $USER:$USER /home/$USER
chmod -R 755 /home/$USER

# Re-Install Website
rm -rf /home/${USER}/${SERVER_NAME}
mkdir -p /home/${USER}/${SERVER_NAME}
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
sed -i "s/^\(\$api_port='\).*/\1$port';/" /home/${USER}/${SERVER_NAME}/include/config.php
sed -i "s/^\(\$redirectURL='\).*/\1${REDIRECTURL}';/" /home/${USER}/${SERVER_NAME}/include/config.php
sed -i "s/^\(\$ipnURL='\).*/\1${IPNURL}';/" /home/${USER}/${SERVER_NAME}/include/config.php
sed -i "s/^\(\$api_ver='\).*/\1${apiver}';/" /home/${USER}/${SERVER_NAME}/include/config.php
sed -i "s/^\(\$coldstakeui='\).*/\1${coldstakeui}';/" /home/${USER}/${SERVER_NAME}/include/config.php
sed -i "s/^\(\$payment='\).*/\1${payment}';/" /home/${USER}/${SERVER_NAME}/include/config.php
sed -i "s/^\(\$whitelist='\).*/\1${whitelist}';/" /home/${USER}/${SERVER_NAME}/include/config.php

## Inject hot wallet name & password into keys.php
source /var/secure/credentials.sh
sed -i "s/^\(\$WalletName='\).*/\1${STAKINGNAME}';/" /var/secure/keys.php
sed -i "s/^\(\$WalletPassword='\).*/\1${STAKINGPASSWORD}';/" /var/secure/keys.php

#Inject RPC username & password into config.php
sed -i "s/^\(\$rpc_user='\).*/\1${RPCUSER}';/" /home/${USER}/${SERVER_NAME}/include/config.php
sed -i "s/^\(\$rpc_pass='\).*/\1${RPCPASS}';/" /home/${USER}/${SERVER_NAME}/include/config.php

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