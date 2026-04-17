#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as your normal user, not as root."
  exit 1
fi

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

need_cmd sudo
need_cmd curl
need_cmd grep
need_cmd sed
need_cmd mktemp

echo "Checking OBS installation..."
if ! command -v obs >/dev/null 2>&1; then
  echo "OBS Studio is not installed."
  echo "Install it first with: sudo apt-get install obs-studio"
  exit 1
fi

OBS_VERSION="$(obs --version 2>/dev/null | sed 's/^OBS Studio - //')"
echo "Found OBS Studio ${OBS_VERSION}"

if pgrep -x obs >/dev/null 2>&1; then
  echo
  echo "OBS is currently running."
  echo "Close OBS before running this script so the new plugins load cleanly."
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

PAGE_URL="https://royshil.github.io/obs-backgroundremoval/ubuntu/"
PAGE_HTML="${TMP_DIR}/backgroundremoval-ubuntu.html"
DEB_URL_FILE="${TMP_DIR}/deb-url.txt"
DEB_FILE="${TMP_DIR}/obs-backgroundremoval.deb"

echo
echo "Installing packaged OBS blur filter..."
sudo apt-get update
sudo apt-get install -y obs-ashmanix-blur-filter

echo
echo "Resolving the latest Ubuntu package for OBS Background Removal..."
curl -fsSL "${PAGE_URL}" -o "${PAGE_HTML}"

grep -Eo 'https://[^"]+x86_64-linux-gnu\.deb' "${PAGE_HTML}" > "${DEB_URL_FILE}" || true

if [[ ! -s "${DEB_URL_FILE}" ]]; then
  echo "Could not find the Ubuntu .deb download URL on ${PAGE_URL}"
  echo "Open this page in a browser and download the Ubuntu package manually:"
  echo "  ${PAGE_URL}"
  exit 1
fi

DEB_URL="$(head -n1 "${DEB_URL_FILE}")"
echo "Downloading:"
echo "  ${DEB_URL}"
curl -fL "${DEB_URL}" -o "${DEB_FILE}"

echo
echo "Installing OBS Background Removal plugin..."
sudo dpkg -i "${DEB_FILE}" || sudo apt-get install -f -y

echo
echo "Installed packages:"
dpkg -l | grep -E 'obs-ashmanix-blur-filter|obs-backgroundremoval|obs-studio' || true

echo
echo "Plugin files detected:"
find /usr/lib /usr/share -type f 2>/dev/null | grep -E 'ashmanix|backgroundremoval' || true

cat <<'EOF'

Setup is installed. Finish the effect in OBS like this:

1. Open OBS.
2. Add your webcam source.
3. Add the same webcam a second time:
   choose "Add Existing" so both sources point to the same camera.
4. Put the duplicate webcam source underneath the first one.
5. On the top webcam source:
   Filters -> add "Background Removal" filter.
   Model suggestion: default/portrait segmentation.
   Thread count: start with 2.
6. On the bottom webcam source:
   Filters -> add "Blur" filter.
   Start with a moderate blur radius and adjust from there.
7. Keep the top source sharp and the bottom source blurred.

Result:
- top source = you, cut out from the background
- bottom source = full webcam, blurred
- combined view = blurred background with a sharp subject

If the filter names do not appear immediately, restart OBS once.
EOF
