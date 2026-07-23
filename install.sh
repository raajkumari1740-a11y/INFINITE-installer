#!/usr/bin/env bash

set -e

REPO="https://github.com/raajkumari1740-a11y/INFINITE-installer.git"
DIR="INFINITE-installer"

echo "========================================"
echo "      INFINITE VPS MANAGER INSTALLER"
echo "========================================"

if ! command -v git >/dev/null 2>&1; then
    echo "[INFO] Installing Git..."
    apt update
    apt install -y git
fi

if [ -d "$DIR" ]; then
    echo "[INFO] Updating existing installation..."
    cd "$DIR"
    git pull
else
    echo "[INFO] Cloning repository..."
    git clone "$REPO"
    cd "$DIR"
fi

chmod -R +x .

find . -type f -name "*.sh" -exec chmod +x {} \;

echo
echo "[SUCCESS] Installation complete."
echo

exec bash infinite.sh
