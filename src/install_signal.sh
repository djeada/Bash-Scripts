#!/usr/bin/env bash
set -Eeuo pipefail

readonly KEY_URL="https://updates.signal.org/desktop/apt/keys.asc"
readonly SOURCE_URL="https://updates.signal.org/static/desktop/apt/signal-desktop.sources"
readonly KEYRING_PATH="/usr/share/keyrings/signal-desktop-keyring.gpg"
readonly SOURCE_PATH="/etc/apt/sources.list.d/signal-desktop.sources"

usage() {
  cat <<EOF
Usage: $(basename "$0") [install|upgrade|purge|help]

Commands:
  install   Add Signal's apt repository and install the newest version (default)
  upgrade   Refresh the repository and upgrade an existing Signal installation
  purge     Purge Signal and remove its apt repository and signing key
  help      Show this help text

Examples:
  $(basename "$0")
  $(basename "$0") upgrade
  $(basename "$0") purge
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

setup_repository() (
  local temp_dir
  temp_dir=$(mktemp -d)
  trap 'rm -rf "$temp_dir"' EXIT

  echo "[1/3] Downloading and installing Signal's signing key"
  curl --fail --location --silent --show-error "$KEY_URL" \
    | gpg --batch --yes --dearmor --output "$temp_dir/signal-desktop-keyring.gpg"
  sudo install -Dm644 "$temp_dir/signal-desktop-keyring.gpg" "$KEYRING_PATH"

  echo "[2/3] Downloading and installing Signal's apt source"
  curl --fail --location --silent --show-error \
    --output "$temp_dir/signal-desktop.sources" "$SOURCE_URL"
  sudo install -Dm644 "$temp_dir/signal-desktop.sources" "$SOURCE_PATH"

  echo "[3/3] Updating apt metadata"
  sudo apt-get update
)

install_signal() {
  setup_repository
  echo "Installing the newest Signal Desktop version"
  sudo apt-get install -y signal-desktop
  echo "Signal Desktop installation finished."
}

upgrade_signal() {
  dpkg-query -W -f='${Status}' signal-desktop 2>/dev/null \
    | grep -q '^install ok installed$' \
    || die "Signal Desktop is not installed; run '$0 install' first."

  setup_repository
  echo "Upgrading Signal Desktop to the newest available version"
  sudo apt-get install -y --only-upgrade signal-desktop
  echo "Signal Desktop upgrade finished."
}

purge_signal() {
  echo "Purging Signal Desktop"
  if dpkg-query -W -f='${Status}' signal-desktop 2>/dev/null \
    | grep -q '^install ok installed$'; then
    sudo apt-get purge -y signal-desktop
  else
    echo "Signal Desktop is not installed; skipping package removal."
  fi

  echo "Removing Signal's apt source and signing key"
  sudo rm -f -- "$SOURCE_PATH" "$KEYRING_PATH"
  sudo apt-get update
  echo "Signal Desktop purge finished. User data in ~/.config/Signal was kept."
}

main() {
  local action=${1:-install}
  (( $# <= 1 )) || die "Too many arguments. Run '$0 help' for usage."

  case "$action" in
    install|--install|-i)
      require_command curl
      require_command gpg
      require_command sudo
      require_command apt-get
      install_signal
      ;;
    upgrade|--upgrade|-u)
      require_command curl
      require_command gpg
      require_command sudo
      require_command apt-get
      require_command dpkg-query
      require_command grep
      upgrade_signal
      ;;
    purge|--purge|-p)
      require_command sudo
      require_command apt-get
      require_command dpkg-query
      require_command grep
      purge_signal
      ;;
    help|--help|-h)
      usage
      ;;
    *)
      usage >&2
      die "Unknown command: $action"
      ;;
  esac
}

main "$@"
