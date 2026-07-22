#!/usr/bin/env bash

# ==========================================================
# INFINITE VPS MANAGER
# Dependencies Installer
# ==========================================================

GREEN='\033[1;32m'
WHITE='\033[1;37m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'

clear

echo -e "${GREEN}"
echo "=========================================================="
echo "          INSTALLING REQUIRED DEPENDENCIES"
echo "=========================================================="
echo -e "${RESET}"

if [[ $EUID -ne 0 ]]; then

    echo -e "${RED}Please run as root!${RESET}"

    exit 1

fi

echo
echo -e "${YELLOW}Updating Package Lists...${RESET}"
echo

apt update -y

echo
echo -e "${YELLOW}Upgrading System...${RESET}"
echo

apt upgrade -y

echo
echo -e "${YELLOW}Installing Required Packages...${RESET}"
echo

apt install -y \
curl \
wget \
git \
unzip \
zip \
tar \
nano \
sudo \
software-properties-common \
ca-certificates \
lsb-release \
apt-transport-https \
gnupg \
cron \
ufw \
fail2ban

echo
echo -e "${GREEN}Basic Packages Installed Successfully.${RESET}"
echo

# ==========================================================
# INSTALL PHP 8.3
# ==========================================================

echo
echo -e "${YELLOW}Installing PHP 8.3...${RESET}"
echo

add-apt-repository ppa:ondrej/php -y

apt update -y

apt install -y \
php8.3 \
php8.3-cli \
php8.3-fpm \
php8.3-gd \
php8.3-mysql \
php8.3-mbstring \
php8.3-bcmath \
php8.3-xml \
php8.3-curl \
php8.3-zip \
php8.3-intl \
php8.3-common


# =================================================

# ==========================================================
# START SERVICES
# ==========================================================

echo
echo -e "${YELLOW}Starting Services...${RESET}"
echo

systemctl enable nginx
systemctl restart nginx

systemctl enable mariadb
systemctl restart mariadb

systemctl enable redis-server
systemctl restart redis-server


# ==========================================================
# CONFIGURE FIREWALL
# ==========================================================

echo
echo -e "${YELLOW}Configuring Firewall...${RESET}"
echo

ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp

ufw --force enable


# ==========================================================
# ENABLE FAIL2BAN
# ==========================================================

echo
echo -e "${YELLOW}Starting Fail2Ban...${RESET}"
echo

systemctl enable fail2ban
systemctl restart fail2ban


# ==========================================================
# VERIFY INSTALLATION
# ==========================================================

echo
echo -e "${YELLOW}Verifying Installation...${RESET}"
echo

php -v
composer --version
nginx -v
node -v
npm -v
redis-server --version
mysql --version

echo


# ==========================================================
# INSTALLATION COMPLETE
# ==========================================================

echo -e "${GREEN}"
echo "=========================================================="
echo "      ALL DEPENDENCIES INSTALLED SUCCESSFULLY!"
echo "=========================================================="
echo -e "${RESET}"

echo
echo "PHP        : Installed"
echo "Composer   : Installed"
echo "MariaDB    : Installed"
echo "Redis      : Installed"
echo "Nginx      : Installed"
echo "Node.js    : Installed"
echo "Certbot    : Installed"
echo "Firewall   : Enabled"
echo "Fail2Ban   : Enabled"

echo

read -rp "Press Enter to continue..."
