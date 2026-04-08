#!/usr/bin/env bash
set -Eeuo pipefail

KEY_URL="https://updates.signal.org/desktop/apt/keys.asc"
SOURCE_URL="https://updates.signal.org/static/desktop/apt/signal-desktop.sources"
KEYRING_NAME="signal-desktop-keyring.gpg"
SOURCE_NAME="signal-desktop.sources"

cleanup() {
  rm -f "$KEYRING_NAME" "$SOURCE_NAME"
}

trap cleanup EXIT

echo "[1/5] Downloading Signal signing key"
wget -O- "$KEY_URL" | gpg --dearmor > "$KEYRING_NAME"

echo "[2/5] Installing signing key to /usr/share/keyrings"
sudo install -Dm644 "$KEYRING_NAME" "/usr/share/keyrings/$KEYRING_NAME"

echo "[3/5] Downloading Signal apt source file"
wget -O "$SOURCE_NAME" "$SOURCE_URL"

echo "[4/5] Installing apt source file to /etc/apt/sources.list.d"
sudo install -Dm644 "$SOURCE_NAME" "/etc/apt/sources.list.d/$SOURCE_NAME"

echo "[5/5] Updating apt metadata and installing Signal Desktop"
sudo apt update
sudo apt install -y signal-desktop

echo "Signal Desktop installation finished."
