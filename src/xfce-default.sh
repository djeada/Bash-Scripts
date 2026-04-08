#!/usr/bin/env bash

# Script Name: xfce-default.sh
# Description: Installs the XFCE desktop on Linux Mint and configures LightDM
#              to use it as the default session. Optionally sets a per-user
#              default via ~/.dmrc.
# Usage: sudo bash xfce-default.sh [OPTIONS]
# Options:
#   -u, --user USER   Set XFCE as the default session for USER via ~/.dmrc.
#   -h, --help        Display this help message and exit.
# Example: sudo bash xfce-default.sh --user alice

set -euo pipefail

# Constants
LIGHTDM_CONF="/etc/lightdm/lightdm.conf.d/70-linuxmint.conf"
BACKUP_DIR="/root/xfce-setup-backups"
XFCE_SESSION_FILE="/usr/share/xsessions/xfce.desktop"
XFCE_PACKAGE="mint-meta-xfce"

###############################################################################
# display_help: Print usage information and exit
###############################################################################
display_help() {
    cat <<EOF
Usage: sudo bash $0 [OPTIONS]

Installs the XFCE desktop on Linux Mint and configures LightDM to use it as
the default session. Optionally sets a per-user default via ~/.dmrc.

Options:
  -u, --user USER   Set XFCE as the default session for USER via ~/.dmrc.
  -h, --help        Display this help message and exit.

Example:
  sudo bash $0 --user alice
EOF
    exit 0
}

###############################################################################
# log: Print a prefixed status message
###############################################################################
log() {
    printf '==> %s\n' "$1"
}

###############################################################################
# need_cmd: Verify that a required command is available
###############################################################################
need_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

###############################################################################
# check_root: Ensure the script is running as root
###############################################################################
check_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo "Run this script as root: sudo bash $0" >&2
        exit 1
    fi
}

###############################################################################
# detect_os: Source /etc/os-release and warn if not Linux Mint
###############################################################################
detect_os() {
    log "Detecting OS"
    if [[ -r /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        echo "Detected: ${PRETTY_NAME:-unknown}"
    else
        echo "Cannot read /etc/os-release" >&2
        exit 1
    fi

    if [[ "${ID:-}" != "linuxmint" ]]; then
        echo "This script was prepared for Linux Mint. Review before continuing."
    fi
}

###############################################################################
# install_xfce: Update APT metadata and install the XFCE meta-package
###############################################################################
install_xfce() {
    log "Updating APT metadata"
    apt-get update

    log "Installing XFCE desktop packages"
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${XFCE_PACKAGE}"
}

###############################################################################
# configure_lightdm: Back up LightDM config and set XFCE as default session
###############################################################################
configure_lightdm() {
    local timestamp
    timestamp="$(date +%Y%m%d-%H%M%S)"
    local backup_file="${BACKUP_DIR}/70-linuxmint.conf.${timestamp}.bak"

    mkdir -p "${BACKUP_DIR}"

    log "Verifying LightDM config exists"
    if [[ ! -f "${LIGHTDM_CONF}" ]]; then
        echo "Expected LightDM config not found: ${LIGHTDM_CONF}" >&2
        exit 1
    fi

    log "Backing up LightDM config to ${backup_file}"
    cp -a "${LIGHTDM_CONF}" "${backup_file}"

    log "Setting LightDM default session to XFCE"
    if grep -q '^user-session=' "${LIGHTDM_CONF}"; then
        sed -i 's/^user-session=.*/user-session=xfce/' "${LIGHTDM_CONF}"
    else
        printf '\n[Seat:*]\nuser-session=xfce\n' >> "${LIGHTDM_CONF}"
    fi
}

###############################################################################
# verify_session: Confirm the XFCE session desktop file is present
###############################################################################
verify_session() {
    log "Verifying XFCE session file"
    if [[ ! -f "${XFCE_SESSION_FILE}" ]]; then
        echo "XFCE session file missing: ${XFCE_SESSION_FILE}" >&2
        exit 1
    fi

    log "Current LightDM session setting"
    grep '^user-session=' "${LIGHTDM_CONF}" || true
}

###############################################################################
# set_user_session: Write ~/.dmrc for a given user so XFCE is their default
###############################################################################
set_user_session() {
    local target_user="$1"
    local user_home

    user_home="$(getent passwd "${target_user}" | cut -d: -f6 || true)"
    if [[ -z "${user_home}" || ! -d "${user_home}" ]]; then
        echo "User '${target_user}' not found or home directory missing" >&2
        exit 1
    fi

    cat > "${user_home}/.dmrc" <<'EODMRC'
[Desktop]
Session=xfce
EODMRC

    chown "${target_user}:${target_user}" "${user_home}/.dmrc"
    chmod 644 "${user_home}/.dmrc"
    echo "Per-user session written to ${user_home}/.dmrc"
}

###############################################################################
# main: Parse arguments and orchestrate the setup
###############################################################################
main() {
    local target_user=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                display_help
                ;;
            -u|--user)
                if [[ -z "${2:-}" ]]; then
                    echo "Option $1 requires a username argument." >&2
                    exit 1
                fi
                target_user="$2"
                shift
                ;;
            *)
                echo "Unknown option: $1" >&2
                display_help
                ;;
        esac
        shift
    done

    check_root

    need_cmd apt-get
    need_cmd sed
    need_cmd grep
    need_cmd getent
    need_cmd cp

    detect_os
    install_xfce
    configure_lightdm
    verify_session

    if [[ -n "${target_user}" ]]; then
        set_user_session "${target_user}"
    elif [[ -t 0 ]]; then
        log "Optional: set XFCE as the default for an existing user via ~/.dmrc"
        read -r -p "Enter a username to set per-user default session, or press Enter to skip: " target_user
        if [[ -n "${target_user}" ]]; then
            set_user_session "${target_user}"
        fi
    fi

    log "Done"
    echo "Log out and log back in. XFCE should be the default session."
    echo "If needed, reboot to ensure the display manager fully picks up the change."
}

main "$@"
