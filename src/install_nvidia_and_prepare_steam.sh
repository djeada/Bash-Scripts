#!/usr/bin/env bash

# Script Name: install_nvidia_and_prepare_steam.sh
# Description: Installs the recommended NVIDIA driver on Ubuntu and checks Steam GPU integration.
# Usage: sudo ./install_nvidia_and_prepare_steam.sh
# Example: sudo ./install_nvidia_and_prepare_steam.sh

set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script as root:"
  echo "  sudo bash $0"
  exit 1
fi

log() {
  printf '\n==> %s\n' "$1"
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

need_cmd apt-get
need_cmd ubuntu-drivers
need_cmd lspci
need_cmd grep
need_cmd awk
need_cmd sed

log "Detecting NVIDIA GPU"
if ! lspci -nn | grep -qi 'NVIDIA'; then
  echo "No NVIDIA GPU detected. Exiting."
  exit 1
fi

log "Finding recommended NVIDIA driver"
recommended_driver="$(
  ubuntu-drivers devices 2>/dev/null \
    | awk '/recommended/ && /nvidia-driver-/ { print $3; exit }'
)"

if [[ -z "${recommended_driver}" ]]; then
  echo "Could not determine a recommended NVIDIA driver from ubuntu-drivers."
  echo "Output follows:"
  ubuntu-drivers devices || true
  exit 1
fi

echo "Recommended package: ${recommended_driver}"

log "Updating package lists"
apt-get update

log "Installing ${recommended_driver}"
DEBIAN_FRONTEND=noninteractive apt-get install -y "${recommended_driver}"

log "Checking for a Steam desktop entry"
steam_desktop=""
if [[ -f /home/adam/.local/share/applications/steam.desktop ]]; then
  steam_desktop="/home/adam/.local/share/applications/steam.desktop"
elif [[ -f /usr/share/applications/steam.desktop ]]; then
  steam_desktop="/usr/share/applications/steam.desktop"
fi

if [[ -n "${steam_desktop}" ]]; then
  echo "Steam desktop entry: ${steam_desktop}"
  if grep -q '^PrefersNonDefaultGPU=true$' "${steam_desktop}"; then
    echo "Steam already requests the non-default GPU."
  else
    echo "Steam desktop entry does not contain PrefersNonDefaultGPU=true."
    echo "That is optional once the NVIDIA driver is active system-wide."
  fi
else
  echo "Steam desktop entry not found. Skipping Steam check."
fi

log "Current kernel module status"
lsmod | grep -E 'nvidia|nouveau' || true

cat <<'EOF'

Installation finished.

Next step:
  reboot

After reboot, verify with:
  nvidia-smi
  lsmod | grep -E 'nvidia|nouveau'
  glxinfo -B | grep -E 'OpenGL vendor|OpenGL renderer'

Expected:
  - nvidia-smi works
  - nvidia modules are loaded
  - nouveau is not the active driver
  - Steam can use the NVIDIA stack normally
EOF

