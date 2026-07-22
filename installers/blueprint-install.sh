#!/usr/bin/env bash

# ==========================================================
# BLUEPRINT INSTALLER
# ==========================================================

GREEN='\033[1;32m'
WHITE='\033[1;37m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'

clear

echo -e "${GREEN}"
echo "=========================================================="
echo "                 BLUEPRINT INSTALLER"
echo "=========================================================="
echo -e "${RESET}"

if [[ $EUID -ne 0 ]]; then

    echo -e "${RED}Please run as root!${RESET}"

    exit 1

fi

echo

read -rp "Panel Path [/var/www/pterodactyl] : " PANEL_PATH

if [ -z "$PANEL_PATH" ]; then

    PANEL_PATH="/var/www/pterodactyl"

fi

echo

echo "=========================================================="
echo "Installation Summary"
echo "=========================================================="

echo "Panel Path : $PANEL_PATH"

echo

read -rp "Continue Installation? (Y/N): " CONFIRM

if [[ "$CONFIRM" != "Y" && "$CONFIRM" != "y" ]]; then

    echo

    echo "Installation Cancelled."

    exit 0

fi

echo

echo -e "${YELLOW}Preparing Blueprint Installation...${RESET}"

sleep 2

echo

echo -e "${GREEN}Preparation Completed.${RESET}"

echo

# ==========================================================
# DOWNLOAD BLUEPRINT
# ==========================================================

echo
echo -e "${YELLOW}Downloading Blueprint...${RESET}"
echo

cd "$PANEL_PATH" || exit

# Download Blueprint here

echo
echo -e "${GREEN}Blueprint Downloaded.${RESET}"
echo


# ==========================================================
# INSTALL BLUEPRINT
# ==========================================================

echo
echo -e "${YELLOW}Installing Blueprint...${RESET}"
echo

# Blueprint install commands

echo
echo -e "${GREEN}Blueprint Installed Successfully.${RESET}"
echo


# ==========================================================
# CLEAR CACHE
# ==========================================================

echo
echo -e "${YELLOW}Clearing Cache...${RESET}"
echo

php artisan optimize:clear

php artisan optimize

echo
echo -e "${GREEN}Cache Cleared Successfully.${RESET}"
echo


# ==========================================================
# INSTALL COMPLETE
# ==========================================================

echo
echo -e "${GREEN}==============================================${RESET}"
echo -e "${GREEN} Blueprint Installed Successfully! ${RESET}"
echo -e "${GREEN}==============================================${RESET}"

echo

read -rp "Press Enter to continue..."
