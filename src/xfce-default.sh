#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root: sudo bash $0"
  exit 1
fi

echo "==> Detecting OS"
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  echo "Detected: ${PRETTY_NAME:-unknown}"
else
  echo "Cannot read /etc/os-release"
  exit 1
fi

if [[ "${ID:-}" != "linuxmint" ]]; then
  echo "This script was prepared for Linux Mint. Review before continuing."
fi

LIGHTDM_CONF="/etc/lightdm/lightdm.conf.d/70-linuxmint.conf"
BACKUP_DIR="/root/xfce-setup-backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/70-linuxmint.conf.${TIMESTAMP}.bak"

mkdir -p "${BACKUP_DIR}"

echo "==> Updating APT metadata"
apt-get update

echo "==> Installing XFCE desktop packages"
DEBIAN_FRONTEND=noninteractive apt-get install -y mint-meta-xfce

echo "==> Verifying LightDM config exists"
if [[ ! -f "${LIGHTDM_CONF}" ]]; then
  echo "Expected LightDM config not found: ${LIGHTDM_CONF}"
  exit 1
fi

echo "==> Backing up LightDM config to ${BACKUP_FILE}"
cp -a "${LIGHTDM_CONF}" "${BACKUP_FILE}"

echo "==> Setting LightDM default session to XFCE"
if grep -q '^user-session=' "${LIGHTDM_CONF}"; then
  sed -i 's/^user-session=.*/user-session=xfce/' "${LIGHTDM_CONF}"
else
  printf '\n[Seat:*]\nuser-session=xfce\n' >> "${LIGHTDM_CONF}"
fi

echo "==> Verifying XFCE session file"
if [[ ! -f /usr/share/xsessions/xfce.desktop ]]; then
  echo "XFCE session file missing: /usr/share/xsessions/xfce.desktop"
  exit 1
fi

echo "==> Current LightDM session setting"
grep '^user-session=' "${LIGHTDM_CONF}" || true

echo "==> Optional: set XFCE as the default for an existing user via ~/.dmrc"
read -r -p "Enter a username to set per-user default session, or press Enter to skip: " TARGET_USER
if [[ -n "${TARGET_USER}" ]]; then
  USER_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6 || true)"
  if [[ -z "${USER_HOME}" || ! -d "${USER_HOME}" ]]; then
    echo "User '${TARGET_USER}' not found or home directory missing"
    exit 1
  fi

  cat > "${USER_HOME}/.dmrc" <<'EODMRC'
[Desktop]
Session=xfce
EODMRC

  chown "${TARGET_USER}:${TARGET_USER}" "${USER_HOME}/.dmrc"
  chmod 644 "${USER_HOME}/.dmrc"
  echo "Per-user session written to ${USER_HOME}/.dmrc"
fi

echo "==> Done"
echo "Log out and log back in. XFCE should be the default session."
echo "If needed, reboot to ensure the display manager fully picks up the change."
