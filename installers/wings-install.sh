#!/usr/bin/env bash

# ==========================================================
# PTERODACTYL WINGS INSTALLER
# ==========================================================

GREEN='\033[1;32m'
WHITE='\033[1;37m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'

clear

echo -e "${GREEN}"
echo "=========================================================="
echo "                 WINGS INSTALLER"
echo "=========================================================="
echo -e "${RESET}"

if [[ $EUID -ne 0 ]]; then

    echo -e "${RED}Please run as root!${RESET}"

    exit 1

fi

echo

read -rp "Panel URL          : " PANEL_URL

read -rp "Node Name          : " NODE_NAME

read -rp "Node FQDN          : " NODE_FQDN

read -rp "Daemon Token       : " DAEMON_TOKEN

echo

echo "=========================================================="
echo "Installation Summary"
echo "=========================================================="

echo "Panel URL : $PANEL_URL"
echo "Node Name : $NODE_NAME"
echo "Node FQDN : $NODE_FQDN"

echo

read -rp "Continue? (Y/N): " CONFIRM

if [[ "$CONFIRM" != "Y" && "$CONFIRM" != "y" ]]; then

    echo

    echo "Installation Cancelled."

    exit 0

fi

echo

echo -e "${YELLOW}Preparing Wings Installation...${RESET}"

sleep 2

echo

echo -e "${GREEN}Preparation Completed.${RESET}"

# ==========================================================
# INSTALL DOCKER
# ==========================================================

echo
echo -e "${YELLOW}Checking Docker...${RESET}"
echo

if ! command -v docker >/dev/null 2>&1; then

    curl -fsSL https://get.docker.com | bash

fi

systemctl enable docker

systemctl restart docker

echo
echo -e "${GREEN}Docker Ready.${RESET}"
echo


# ==========================================================
# DOWNLOAD WINGS
# ==========================================================

echo
echo -e "${YELLOW}Downloading Wings...${RESET}"
echo

mkdir -p /etc/pterodactyl

cd /etc/pterodactyl || exit

curl -L -o wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64

chmod +x wings

echo
echo -e "${GREEN}Wings Downloaded.${RESET}"
echo


# ==========================================================
# CREATE SYSTEMD SERVICE
# ==========================================================

echo
echo -e "${YELLOW}Creating Wings Service...${RESET}"
echo

cat >/etc/systemd/system/wings.service <<EOF
[Unit]
Description=Pterodactyl Wings
After=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
ExecStart=/etc/pterodactyl/wings
Restart=always
StartLimitInterval=180
StartLimitBurst=30

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

systemctl enable wings

systemctl restart wings

echo
echo -e "${GREEN}Wings Service Started.${RESET}"
echo


# ==========================================================
# INSTALL COMPLETE
# ==========================================================

echo
echo -e "${GREEN}==============================================${RESET}"
echo -e "${GREEN} Wings Installed Successfully! ${RESET}"
echo -e "${GREEN}==============================================${RESET}"
echo

read -rp "Press Enter to continue..."
