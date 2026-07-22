#!/usr/bin/env bash

# ==========================================================
# CREATE VPS
# ==========================================================

GREEN='\033[1;32m'
WHITE='\033[1;37m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'

clear

echo -e "${GREEN}"
echo "=========================================================="
echo "                    CREATE VPS"
echo "=========================================================="
echo -e "${RESET}"

if [[ $EUID -ne 0 ]]; then

    echo -e "${RED}Please run as root!${RESET}"

    exit 1

fi

echo

echo "Available Operating Systems"

echo

echo "[1] Ubuntu 24.04"
echo "[2] Ubuntu 22.04"
echo "[3] Debian 12"
echo "[4] Debian 11"

echo

read -rp "Select OS : " OS

echo

read -rp "VPS Name          : " VPS_NAME

read -rp "Hostname          : " HOSTNAME

read -rp "CPU Cores         : " CPU

read -rp "RAM (MB)          : " RAM

read -rp "Disk (GB)         : " DISK

read -rp "Username          : " USERNAME

read -rsp "Password          : " PASSWORD

echo

read -rp "SSH Port [22]     : " SSH_PORT

if [ -z "$SSH_PORT" ]; then

    SSH_PORT="22"

fi

echo

echo "=========================================================="
echo "VPS Configuration"
echo "=========================================================="

echo "OS        : $OS"
echo "Name      : $VPS_NAME"
echo "Hostname  : $HOSTNAME"
echo "CPU       : $CPU Cores"
echo "RAM       : ${RAM}MB"
echo "Disk      : ${DISK}GB"
echo "User      : $USERNAME"
echo "SSH Port  : $SSH_PORT"

echo

read -rp "Create VPS? (Y/N): " CONFIRM

if [[ "$CONFIRM" != "Y" && "$CONFIRM" != "y" ]]; then

    echo

    echo "Operation Cancelled."

    exit 0

fi

echo

echo -e "${YELLOW}Preparing VPS Creation...${RESET}"

sleep 2

echo

echo -e "${GREEN}Configuration Saved.${RESET}"
echo
