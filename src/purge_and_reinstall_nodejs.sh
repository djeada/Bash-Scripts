#!/usr/bin/env bash

# Script Name: purge_and_reinstall_nodejs.sh
# Description: Detects, purges, and optionally reinstalls Node.js/npm using safer
#              defaults. Package-manager installs and official nodejs.org
#              tarballs are supported.
# Usage: purge_and_reinstall_nodejs.sh [options]

set -euo pipefail

VERSION="3.0.0"

DRY_RUN=false
VERBOSE=false
ASSUME_YES=false
PURGE_ONLY=false
PURGE_SYSTEM=false
PURGE_USER_CACHE=false
REMOVE_ALL_VERSION_MANAGERS=false
ALL_USERS=false
NO_PURGE=false
VERIFY_DOWNLOAD=true
ENABLE_COREPACK=false

INSTALL_METHOD=""
INSTALL_CHANNEL=""
INSTALL_VERSION=""
INSTALL_PREFIX="/opt/nodejs"
SYMLINK_DIR="/usr/local/bin"

OS_TYPE=""
DISTRO=""
DISTRO_LIKE=""
ARCH=""
LIBC=""
PKG_MANAGER=""

VERSION_MANAGERS_TO_REMOVE=()
TMP_DIRS=()

cleanup_tmp_dirs() {
    local tmp_dir

    for tmp_dir in "${TMP_DIRS[@]}"; do
        if [[ -n "$tmp_dir" && -d "$tmp_dir" ]]; then
            rm -rf "$tmp_dir"
        fi
    done
}

trap cleanup_tmp_dirs EXIT

print_usage() {
    cat <<EOF
Usage: $0 [options]

Safe default:
  With no options, this script only detects current Node.js installations.

Actions:
  --detect                    Detect installations and exit.
  --purge-only                Purge system Node.js/npm installations only.
  --purge-system              Purge package-managed and unmanaged system installs.
  --purge-user-cache          Remove current user's Node/npm cache files.
  --all-users                 Apply user cleanup to all users; requires root.
  --remove-version-manager M  Remove nvm, fnm, volta, asdf-node, or mise-node.
  --remove-all-version-managers
                              Remove supported Node.js version manager data.

Install:
  --distro, --install-distro  Install from the detected package manager.
  --official                  Install an official nodejs.org tarball; defaults to LTS.
  --lts                       Install latest LTS from nodejs.org.
  --current, --latest         Install latest Current from nodejs.org.
  --version VERSION           Install a specific version from nodejs.org.
  --no-purge                  Install without purging system installations first.
  --install-prefix DIR        Install official tarballs under DIR.
                              Default: /opt/nodejs
  --symlink-dir DIR           Create node/npm/npx/corepack symlinks in DIR.
                              Default: /usr/local/bin
  --skip-verify               Skip checksum/signature verification.
  --enable-corepack           Run corepack enable after official install.

Safety and output:
  -y, --yes                   Do not ask for confirmation.
  -d, --dry-run               Show what would be done without making changes.
  -v, --verbose               Enable verbose output.
  -h, --help                  Display this help message.
  -V, --version-info          Display script version.

Compatibility:
  --skip-user-cleanup         Accepted for older usage; user cleanup is now opt-in.

Examples:
  $0
  $0 --purge-only --dry-run
  $0 --purge-only --yes
  $0 --lts --yes
  $0 --distro --purge-user-cache --yes
  $0 --version 24.15.0 --install-prefix /opt/nodejs --yes
EOF
}

print_version() {
    echo "$0 version $VERSION"
}

log() {
    if [[ "$VERBOSE" == true ]]; then
        echo "[INFO] $*"
    fi
}

log_warn() {
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

die() {
    log_error "$*"
    exit 1
}

run_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would execute: $*"
        return 0
    fi

    log "Executing: $*"
    "$@"
}

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        die "Required command not found: $command_name"
    fi
}

run_as_root() {
    if [[ "$DRY_RUN" == true ]]; then
        if [[ $EUID -eq 0 ]]; then
            echo "[DRY-RUN] Would execute: $*"
        else
            echo "[DRY-RUN] Would execute with sudo: $*"
        fi
        return 0
    fi

    if [[ $EUID -eq 0 ]]; then
        log "Executing as root: $*"
        "$@"
    else
        require_command sudo
        log "Executing with sudo: $*"
        sudo "$@"
    fi
}

remove_root_path() {
    local path="$1"

    case "$path" in
        ""|"/"|"/usr"|"/usr/local"|"/opt"|"/home"|"$HOME")
            die "Refusing to remove unsafe path: $path"
            ;;
    esac

    if [[ -e "$path" || -L "$path" || "$DRY_RUN" == true ]]; then
        run_as_root rm -rf -- "$path"
    fi
}

remove_user_path() {
    local path="$1"

    case "$path" in
        ""|"/"|"$HOME")
            die "Refusing to remove unsafe user path: $path"
            ;;
    esac

    if [[ -e "$path" || -L "$path" || "$DRY_RUN" == true ]]; then
        run_cmd rm -rf -- "$path"
    fi
}

detect_os() {
    local os_name
    os_name=$(uname -s)

    case "$os_name" in
        Darwin)
            OS_TYPE="macos"
            DISTRO="macos"
            DISTRO_LIKE=""
            ;;
        Linux)
            OS_TYPE="linux"
            if [[ -r /etc/os-release ]]; then
                # shellcheck disable=SC1091
                . /etc/os-release
                DISTRO="${ID:-unknown}"
                DISTRO_LIKE="${ID_LIKE:-}"
            else
                DISTRO="unknown"
                DISTRO_LIKE=""
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            OS_TYPE="windows"
            DISTRO="windows"
            DISTRO_LIKE=""
            ;;
        *)
            OS_TYPE="unknown"
            DISTRO="unknown"
            DISTRO_LIKE=""
            ;;
    esac

    log "Detected OS: $OS_TYPE ($DISTRO)"
}

detect_arch() {
    local machine_arch
    machine_arch=$(uname -m)

    case "$machine_arch" in
        x86_64|amd64)
            ARCH="x64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv7l|armv7)
            ARCH="armv7l"
            ;;
        i686|i386)
            ARCH="x86"
            ;;
        ppc64le)
            ARCH="ppc64le"
            ;;
        s390x)
            ARCH="s390x"
            ;;
        *)
            ARCH="$machine_arch"
            log_warn "Unknown architecture: $machine_arch; using it as-is"
            ;;
    esac

    log "Detected architecture: $ARCH"
}

detect_libc() {
    LIBC=""

    if [[ "$OS_TYPE" != "linux" ]]; then
        return
    fi

    if command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi musl; then
        LIBC="musl"
    else
        LIBC="glibc"
    fi

    log "Detected libc: $LIBC"
}

detect_pkg_manager() {
    if [[ "$OS_TYPE" == "macos" ]]; then
        if command -v brew >/dev/null 2>&1; then
            PKG_MANAGER="brew"
        else
            PKG_MANAGER="none"
        fi
    elif [[ "$OS_TYPE" == "linux" ]]; then
        if command -v apt-get >/dev/null 2>&1; then
            PKG_MANAGER="apt"
        elif command -v dnf >/dev/null 2>&1; then
            PKG_MANAGER="dnf"
        elif command -v yum >/dev/null 2>&1; then
            PKG_MANAGER="yum"
        elif command -v pacman >/dev/null 2>&1; then
            PKG_MANAGER="pacman"
        elif command -v zypper >/dev/null 2>&1; then
            PKG_MANAGER="zypper"
        elif command -v apk >/dev/null 2>&1; then
            PKG_MANAGER="apk"
        else
            PKG_MANAGER="none"
        fi
    else
        PKG_MANAGER="none"
    fi

    log "Detected package manager: $PKG_MANAGER"
}

detect_system() {
    detect_os
    detect_arch
    detect_libc
    detect_pkg_manager
}

is_package_owned() {
    local path="$1"

    [[ -e "$path" || -L "$path" ]] || return 1

    case "$PKG_MANAGER" in
        apt)
            command -v dpkg >/dev/null 2>&1 && dpkg -S "$path" >/dev/null 2>&1
            ;;
        dnf|yum|zypper)
            command -v rpm >/dev/null 2>&1 && rpm -qf "$path" >/dev/null 2>&1
            ;;
        pacman)
            command -v pacman >/dev/null 2>&1 && pacman -Qo "$path" >/dev/null 2>&1
            ;;
        apk)
            command -v apk >/dev/null 2>&1 && apk info -W "$path" >/dev/null 2>&1
            ;;
        brew)
            command -v brew >/dev/null 2>&1 && brew list --formula -1 2>/dev/null | grep -qx "node"
            ;;
        *)
            return 1
            ;;
    esac
}

is_unmanaged_system_path() {
    local path="$1"

    case "$path" in
        /usr/local/bin/*|/usr/local/sbin/*|/opt/nodejs/*|/opt/node-v*|/opt/homebrew/bin/*|/opt/local/bin/*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

print_detected_binaries() {
    local binary path version_output owner_note
    local binaries=(node npm npx corepack)

    echo "Detected binaries:"
    for binary in "${binaries[@]}"; do
        path=$(command -v "$binary" 2>/dev/null || true)
        if [[ -z "$path" ]]; then
            echo "  $binary: not found"
            continue
        fi

        version_output=""
        if version_output=$("$path" --version 2>/dev/null); then
            :
        else
            version_output="version unavailable"
        fi

        owner_note="unmanaged or unknown owner"
        if is_package_owned "$path"; then
            owner_note="package-managed"
        fi

        echo "  $binary: $path ($version_output, $owner_note)"
    done
}

print_detected_version_managers() {
    local found=false
    local xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"

    echo "Detected version-manager data:"

    if [[ -d "$HOME/.nvm" ]]; then
        echo "  nvm: $HOME/.nvm"
        found=true
    fi
    if [[ -d "$HOME/.fnm" ]]; then
        echo "  fnm: $HOME/.fnm"
        found=true
    fi
    if [[ -d "$xdg_data_home/fnm" ]]; then
        echo "  fnm: $xdg_data_home/fnm"
        found=true
    fi
    if [[ -d "$HOME/.volta" ]]; then
        echo "  volta: $HOME/.volta"
        found=true
    fi
    if [[ -d "$HOME/.asdf/installs/nodejs" ]]; then
        echo "  asdf-node: $HOME/.asdf/installs/nodejs"
        found=true
    fi
    if [[ -d "$xdg_data_home/mise/installs/node" ]]; then
        echo "  mise-node: $xdg_data_home/mise/installs/node"
        found=true
    fi

    if [[ "$found" == false ]]; then
        echo "  none found"
    fi
}

detect_installations() {
    echo "System: $OS_TYPE ($DISTRO${DISTRO_LIKE:+, like $DISTRO_LIKE}) on $ARCH${LIBC:+/$LIBC}"
    echo "Package manager: $PKG_MANAGER"
    echo
    print_detected_binaries
    echo
    print_detected_version_managers
}

purge_pkg_manager() {
    echo "Purging package-managed Node.js/npm installations..."

    case "$PKG_MANAGER" in
        apt)
            run_as_root apt-get purge -y nodejs npm
            run_as_root apt-get autoremove -y
            ;;
        dnf)
            run_as_root dnf remove -y nodejs npm
            ;;
        yum)
            run_as_root yum remove -y nodejs npm
            ;;
        pacman)
            run_as_root pacman -Rns --noconfirm nodejs npm
            ;;
        zypper)
            run_as_root zypper remove -y nodejs npm
            ;;
        apk)
            run_as_root apk del nodejs npm
            ;;
        brew)
            run_cmd brew uninstall node
            ;;
        none)
            log "No supported package manager detected; skipping package purge"
            ;;
    esac
}

purge_unmanaged_system_install() {
    local binary path
    local binaries=(node npm npx corepack)
    local dirs_to_remove=(
        "$INSTALL_PREFIX"
        "/usr/local/lib/node_modules"
        "/usr/local/include/node"
        "/usr/local/share/doc/node"
    )

    if [[ "$INSTALL_PREFIX" != "/opt/nodejs" ]]; then
        dirs_to_remove+=("/opt/nodejs")
    fi

    echo "Purging unmanaged system Node.js/npm files..."

    for binary in "${binaries[@]}"; do
        path=$(command -v "$binary" 2>/dev/null || true)
        if [[ -z "$path" ]]; then
            continue
        fi

        if is_package_owned "$path"; then
            log "Skipping package-owned binary: $path"
            continue
        fi

        if is_unmanaged_system_path "$path"; then
            remove_root_path "$path"
        else
            log_warn "Skipping $path; it is outside known unmanaged prefixes"
        fi
    done

    for path in "${dirs_to_remove[@]}"; do
        remove_root_path "$path"
    done

    if [[ -d /usr/local/share/man/man1 || "$DRY_RUN" == true ]]; then
        run_as_root find /usr/local/share/man/man1 -maxdepth 1 -type f \
            \( -name "node.*" -o -name "npm.*" -o -name "npx.*" -o -name "corepack.*" \) -delete
    fi
}

purge_system_installations() {
    purge_pkg_manager || log_warn "Package-manager purge had non-fatal errors"
    purge_unmanaged_system_install
}

user_home_dirs() {
    if [[ "$ALL_USERS" == false ]]; then
        printf '%s\n' "$HOME"
        return
    fi

    if [[ $EUID -ne 0 && "$DRY_RUN" == false ]]; then
        die "--all-users requires root"
    fi

    if command -v getent >/dev/null 2>&1; then
        getent passwd | awk -F: '$6 ~ /^\// {print $6}' | sort -u
    elif [[ "$OS_TYPE" == "macos" && -d /Users ]]; then
        find /Users -mindepth 1 -maxdepth 1 -type d
    elif [[ -d /home ]]; then
        find /home -mindepth 1 -maxdepth 1 -type d
    else
        printf '%s\n' "$HOME"
    fi
}

remove_user_path_for_home() {
    local home_dir="$1"
    local relative_path="$2"
    local full_path="$home_dir/$relative_path"

    if [[ "$ALL_USERS" == true && "$home_dir" != "$HOME" ]]; then
        if [[ -e "$full_path" || -L "$full_path" || "$DRY_RUN" == true ]]; then
            run_as_root rm -rf -- "$full_path"
        fi
    else
        remove_user_path "$full_path"
    fi
}

purge_user_cache() {
    local home_dir
    local cache_paths=(
        ".npm/_cacache"
        ".npm/_logs"
        ".node-gyp"
        ".cache/node-gyp"
        ".node_repl_history"
        ".config/configstore/update-notifier-npm.json"
    )

    echo "Purging Node.js/npm user cache files..."

    while IFS= read -r home_dir; do
        [[ -n "$home_dir" && -d "$home_dir" ]] || continue
        log "Cleaning cache under $home_dir"

        local relative_path
        for relative_path in "${cache_paths[@]}"; do
            remove_user_path_for_home "$home_dir" "$relative_path"
        done
    done < <(user_home_dirs)
}

remove_version_manager_for_home() {
    local home_dir="$1"
    local manager="$2"
    local xdg_data_home

    if [[ "$home_dir" == "$HOME" ]]; then
        xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    else
        xdg_data_home="$home_dir/.local/share"
    fi

    case "$manager" in
        nvm)
            remove_user_path_for_home "$home_dir" ".nvm"
            ;;
        fnm)
            remove_user_path_for_home "$home_dir" ".fnm"
            if [[ "$ALL_USERS" == true && "$home_dir" != "$HOME" ]]; then
                run_as_root rm -rf -- "$home_dir/.local/share/fnm"
            else
                remove_user_path "$xdg_data_home/fnm"
            fi
            ;;
        volta)
            remove_user_path_for_home "$home_dir" ".volta"
            ;;
        asdf-node|asdf)
            remove_user_path_for_home "$home_dir" ".asdf/installs/nodejs"
            remove_user_path_for_home "$home_dir" ".asdf/plugins/nodejs"
            ;;
        mise-node|mise)
            if [[ "$ALL_USERS" == true && "$home_dir" != "$HOME" ]]; then
                run_as_root rm -rf -- "$home_dir/.local/share/mise/installs/node"
            else
                remove_user_path "$xdg_data_home/mise/installs/node"
            fi
            ;;
        *)
            die "Unsupported version manager: $manager"
            ;;
    esac
}

remove_version_managers() {
    local manager home_dir

    if [[ "$REMOVE_ALL_VERSION_MANAGERS" == true ]]; then
        VERSION_MANAGERS_TO_REMOVE=(nvm fnm volta asdf-node mise-node)
    fi

    if [[ ${#VERSION_MANAGERS_TO_REMOVE[@]} -eq 0 ]]; then
        return
    fi

    echo "Removing selected Node.js version-manager data..."

    while IFS= read -r home_dir; do
        [[ -n "$home_dir" && -d "$home_dir" ]] || continue
        for manager in "${VERSION_MANAGERS_TO_REMOVE[@]}"; do
            remove_version_manager_for_home "$home_dir" "$manager"
        done
    done < <(user_home_dirs)
}

curl_fetch() {
    local url="$1"
    require_command curl
    curl -fsSL "$url"
}

fetch_latest_version() {
    local json version

    json=$(curl_fetch "https://nodejs.org/dist/index.json")

    if command -v jq >/dev/null 2>&1; then
        version=$(printf '%s' "$json" | jq -r '.[0].version | ltrimstr("v")')
    else
        version=$(printf '%s' "$json" | tr '{' '\n' | sed -n 's/.*"version":"v\([^"]*\)".*/\1/p' | head -n 1)
    fi

    [[ -n "$version" && "$version" != "null" ]] || die "Failed to fetch latest Node.js version"
    printf '%s\n' "$version"
}

fetch_lts_version() {
    local json version

    json=$(curl_fetch "https://nodejs.org/dist/index.json")

    if command -v jq >/dev/null 2>&1; then
        version=$(printf '%s' "$json" | jq -r '.[] | select(.lts != false) | .version' | head -n 1 | sed 's/^v//')
    else
        version=$(printf '%s' "$json" | tr '{' '\n' | grep '"version":"v' | grep -v '"lts":false' | sed -n 's/.*"version":"v\([^"]*\)".*/\1/p' | head -n 1 || true)
    fi

    [[ -n "$version" && "$version" != "null" ]] || die "Failed to fetch latest LTS Node.js version"
    printf '%s\n' "$version"
}

normalize_version() {
    local version="$1"
    version="${version#v}"

    if [[ ! "$version" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]]; then
        die "Version must look like 24.15.0, got: $1"
    fi

    printf '%s\n' "$version"
}

official_platform() {
    case "$OS_TYPE" in
        linux)
            if [[ "$LIBC" == "musl" ]]; then
                die "Official nodejs.org Linux tarballs target glibc. Use --distro on musl/Alpine, or a version manager that supports your platform."
            fi
            printf '%s\n' "linux"
            ;;
        macos)
            printf '%s\n' "darwin"
            ;;
        *)
            die "Official tarball installation is unsupported for OS type: $OS_TYPE"
            ;;
    esac
}

official_archive_ext() {
    case "$OS_TYPE" in
        linux)
            printf '%s\n' "tar.xz"
            ;;
        macos)
            printf '%s\n' "tar.gz"
            ;;
        *)
            die "Unsupported OS for official archive: $OS_TYPE"
            ;;
    esac
}

check_official_artifact_exists() {
    local url="$1"
    local output

    require_command curl

    if ! output=$(curl -fsI "$url" 2>&1); then
        die "Could not access official Node.js artifact: $url
curl said: $output"
    fi
}

checksum_file() {
    local file="$1"

    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        die "Need sha256sum or shasum to verify downloads"
    fi
}

download_and_verify_archive() {
    local version="$1"
    local filename="$2"
    local tmp_dir="$3"
    local base_url="https://nodejs.org/dist/v${version}"
    local archive_url="$base_url/$filename"
    local shasums_file="$tmp_dir/SHASUMS256.txt"
    local expected actual

    echo "Downloading Node.js v${version}..."
    run_cmd curl -fsSL "$archive_url" -o "$tmp_dir/$filename"

    if [[ "$VERIFY_DOWNLOAD" == false ]]; then
        log_warn "Skipping checksum verification because --skip-verify was used"
        return
    fi

    echo "Verifying archive checksum..."

    if command -v gpgv >/dev/null 2>&1; then
        local keyring="$tmp_dir/nodejs-keyring.kbx"
        local signed_shasums="$tmp_dir/SHASUMS256.txt.asc"
        run_cmd curl -fsSL "https://github.com/nodejs/release-keys/raw/refs/heads/main/gpg/pubring.kbx" -o "$keyring"
        run_cmd curl -fsSL "$base_url/SHASUMS256.txt.asc" -o "$signed_shasums"
        if [[ "$DRY_RUN" == false ]]; then
            gpgv --keyring "$keyring" --output "$shasums_file" "$signed_shasums"
        else
            echo "[DRY-RUN] Would verify SHASUMS256.txt.asc with gpgv"
        fi
    else
        log_warn "gpgv is not available; falling back to unsigned SHASUMS256.txt over HTTPS"
        run_cmd curl -fsSL "$base_url/SHASUMS256.txt" -o "$shasums_file"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would compare SHA-256 checksum for $filename"
        return
    fi

    expected=$(awk -v file="$filename" '$2 == file {print $1}' "$shasums_file")
    [[ -n "$expected" ]] || die "Checksum for $filename not found in SHASUMS256.txt"

    actual=$(checksum_file "$tmp_dir/$filename")
    if [[ "$actual" != "$expected" ]]; then
        die "Checksum mismatch for $filename"
    fi
}

install_via_pkg_manager() {
    echo "Installing Node.js via package manager ($PKG_MANAGER)..."

    case "$PKG_MANAGER" in
        apt)
            run_as_root apt-get update
            run_as_root apt-get install -y nodejs npm
            ;;
        dnf)
            run_as_root dnf install -y nodejs npm
            ;;
        yum)
            run_as_root yum install -y nodejs npm
            ;;
        pacman)
            run_as_root pacman -S --noconfirm nodejs npm
            ;;
        zypper)
            run_as_root zypper install -y nodejs npm
            ;;
        apk)
            run_as_root apk add nodejs npm
            ;;
        brew)
            run_cmd brew install node
            ;;
        none)
            die "No supported package manager found. Cannot install via distro."
            ;;
    esac
}

install_from_nodejs_org() {
    local version="$1"
    local platform archive_ext filename download_url tmp_dir extract_dir target_dir
    local binary

    platform=$(official_platform)
    archive_ext=$(official_archive_ext)
    filename="node-v${version}-${platform}-${ARCH}.${archive_ext}"
    download_url="https://nodejs.org/dist/v${version}/${filename}"
    target_dir="$INSTALL_PREFIX/node-v${version}-${platform}-${ARCH}"

    check_official_artifact_exists "$download_url"

    tmp_dir=$(mktemp -d)
    TMP_DIRS+=("$tmp_dir")
    extract_dir="$tmp_dir/extract"
    mkdir -p "$extract_dir"

    echo "Installing Node.js v${version} for ${platform}-${ARCH}..."
    log "Download URL: $download_url"
    log "Install target: $target_dir"

    download_and_verify_archive "$version" "$filename" "$tmp_dir"

    if [[ "$DRY_RUN" == false ]]; then
        echo "Extracting archive..."
        case "$archive_ext" in
            tar.xz)
                require_command tar
                tar -C "$extract_dir" --strip-components=1 -xJf "$tmp_dir/$filename"
                ;;
            tar.gz)
                require_command tar
                tar -C "$extract_dir" --strip-components=1 -xzf "$tmp_dir/$filename"
                ;;
        esac
    else
        echo "[DRY-RUN] Would extract $filename"
    fi

    run_as_root mkdir -p "$INSTALL_PREFIX" "$SYMLINK_DIR"
    remove_root_path "$target_dir"

    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would move extracted Node.js files to: $target_dir"
    else
        run_as_root mv "$extract_dir" "$target_dir"
    fi

    for binary in node npm npx corepack; do
        if [[ "$DRY_RUN" == true || -e "$target_dir/bin/$binary" ]]; then
            run_as_root ln -sfn "$target_dir/bin/$binary" "$SYMLINK_DIR/$binary"
        fi
    done

    if [[ "$ENABLE_COREPACK" == true ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            echo "[DRY-RUN] Would run: $SYMLINK_DIR/corepack enable"
        elif [[ -x "$SYMLINK_DIR/corepack" ]]; then
            run_as_root "$SYMLINK_DIR/corepack" enable
        else
            log_warn "corepack was not installed; skipping corepack enable"
        fi
    fi

    rm -rf "$tmp_dir"

    if [[ "$DRY_RUN" == false ]]; then
        echo "Verifying installation..."
        "$target_dir/bin/node" --version
        "$target_dir/bin/npm" --version

        case ":$PATH:" in
            *":$SYMLINK_DIR:"*)
                :
                ;;
            *)
                log_warn "$SYMLINK_DIR is not in PATH; add it or call binaries from $target_dir/bin"
                ;;
        esac
    fi
}

resolve_official_version() {
    local version

    case "$INSTALL_CHANNEL" in
        current)
            version=$(fetch_latest_version)
            ;;
        lts|"")
            version=$(fetch_lts_version)
            ;;
        version)
            version=$(normalize_version "$INSTALL_VERSION")
            ;;
        *)
            die "Unknown official install channel: $INSTALL_CHANNEL"
            ;;
    esac

    printf '%s\n' "$version"
}

planned_actions() {
    local manager

    echo "Planned actions:"

    if [[ "$PURGE_SYSTEM" == true ]]; then
        echo "  - Purge system Node.js/npm installations"
    fi
    if [[ "$PURGE_USER_CACHE" == true ]]; then
        if [[ "$ALL_USERS" == true ]]; then
            echo "  - Purge Node.js/npm cache files for all users"
        else
            echo "  - Purge Node.js/npm cache files for current user"
        fi
    fi
    if [[ "$REMOVE_ALL_VERSION_MANAGERS" == true ]]; then
        echo "  - Remove all supported Node.js version-manager data"
    elif [[ ${#VERSION_MANAGERS_TO_REMOVE[@]} -gt 0 ]]; then
        for manager in "${VERSION_MANAGERS_TO_REMOVE[@]}"; do
            echo "  - Remove version-manager data: $manager"
        done
    fi
    case "$INSTALL_METHOD" in
        distro)
            echo "  - Install Node.js/npm via package manager"
            ;;
        official)
            case "$INSTALL_CHANNEL" in
                current)
                    echo "  - Install latest Current from nodejs.org into $INSTALL_PREFIX"
                    ;;
                version)
                    echo "  - Install Node.js v$INSTALL_VERSION from nodejs.org into $INSTALL_PREFIX"
                    ;;
                lts|"")
                    echo "  - Install latest LTS from nodejs.org into $INSTALL_PREFIX"
                    ;;
            esac
            ;;
    esac

    if [[ "$PURGE_SYSTEM" == false && "$PURGE_USER_CACHE" == false && "$REMOVE_ALL_VERSION_MANAGERS" == false \
        && ${#VERSION_MANAGERS_TO_REMOVE[@]} -eq 0 && -z "$INSTALL_METHOD" ]]; then
        echo "  - Detect only"
    fi
}

needs_confirmation() {
    [[ "$PURGE_SYSTEM" == true ]] && return 0
    [[ "$PURGE_USER_CACHE" == true ]] && return 0
    [[ "$REMOVE_ALL_VERSION_MANAGERS" == true ]] && return 0
    [[ ${#VERSION_MANAGERS_TO_REMOVE[@]} -gt 0 ]] && return 0
    [[ -n "$INSTALL_METHOD" ]] && return 0
    return 1
}

confirm_if_needed() {
    local reply

    if [[ "$DRY_RUN" == true || "$ASSUME_YES" == true ]]; then
        return
    fi

    needs_confirmation || return 0

    if [[ ! -t 0 ]]; then
        die "Refusing to make changes without an interactive terminal. Re-run with --yes."
    fi

    printf 'Proceed with these changes? [y/N] '
    read -r reply
    case "$reply" in
        y|Y|yes|YES)
            ;;
        *)
            die "Aborted"
            ;;
    esac
}

validate_args() {
    local install_count=0
    local channel_count=0
    local manager

    if [[ -n "$INSTALL_METHOD" ]]; then
        install_count=1
    fi

    case "$INSTALL_PREFIX" in
        /*)
            ;;
        *)
            die "--install-prefix must be an absolute path"
            ;;
    esac

    case "$SYMLINK_DIR" in
        /*)
            ;;
        *)
            die "--symlink-dir must be an absolute path"
            ;;
    esac

    for manager in "${VERSION_MANAGERS_TO_REMOVE[@]}"; do
        case "$manager" in
            nvm|fnm|volta|asdf-node|asdf|mise-node|mise)
                ;;
            *)
                die "Unsupported version manager: $manager"
                ;;
        esac
    done

    if [[ "$INSTALL_CHANNEL" == "current" ]]; then
        channel_count=$((channel_count + 1))
    fi
    if [[ "$INSTALL_CHANNEL" == "lts" ]]; then
        channel_count=$((channel_count + 1))
    fi
    if [[ -n "$INSTALL_VERSION" ]]; then
        channel_count=$((channel_count + 1))
    fi

    if [[ $install_count -gt 1 ]]; then
        die "Only one install method can be specified."
    fi

    if [[ $channel_count -gt 1 ]]; then
        die "Only one of --current, --latest, --lts, or --version can be specified."
    fi

    if [[ -n "$INSTALL_VERSION" ]]; then
        INSTALL_VERSION=$(normalize_version "$INSTALL_VERSION")
        INSTALL_CHANNEL="version"
        if [[ -z "$INSTALL_METHOD" ]]; then
            INSTALL_METHOD="official"
        fi
    fi

    if [[ -n "$INSTALL_CHANNEL" && -z "$INSTALL_METHOD" ]]; then
        INSTALL_METHOD="official"
    fi

    if [[ "$INSTALL_METHOD" == "official" && -z "$INSTALL_CHANNEL" ]]; then
        INSTALL_CHANNEL="lts"
    fi

    if [[ "$PURGE_ONLY" == true && -n "$INSTALL_METHOD" ]]; then
        die "--purge-only cannot be combined with install options"
    fi

    if [[ -n "$INSTALL_METHOD" && "$NO_PURGE" == false && "$PURGE_SYSTEM" == false ]]; then
        PURGE_SYSTEM=true
    fi
}

main() {
    detect_system

    detect_installations
    echo
    planned_actions
    echo

    confirm_if_needed

    if [[ "$PURGE_SYSTEM" == true ]]; then
        echo "=== Purging System Installations ==="
        purge_system_installations
        echo
    fi

    if [[ "$PURGE_USER_CACHE" == true ]]; then
        echo "=== Purging User Cache ==="
        purge_user_cache
        echo
    fi

    if [[ "$REMOVE_ALL_VERSION_MANAGERS" == true || ${#VERSION_MANAGERS_TO_REMOVE[@]} -gt 0 ]]; then
        echo "=== Removing Version-Manager Data ==="
        remove_version_managers
        echo
    fi

    case "$INSTALL_METHOD" in
        distro)
            echo "=== Installing Node.js/npm ==="
            install_via_pkg_manager
            ;;
        official)
            echo "=== Installing Node.js/npm ==="
            local version_to_install
            version_to_install=$(resolve_official_version)
            echo "Resolved Node.js version: v$version_to_install"
            install_from_nodejs_org "$version_to_install"
            ;;
        "")
            ;;
        *)
            die "Unknown install method: $INSTALL_METHOD"
            ;;
    esac

    echo "Done."
}

if [[ $# -eq 0 ]]; then
    main
    exit 0
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --detect)
            shift
            ;;
        --purge-only)
            PURGE_ONLY=true
            PURGE_SYSTEM=true
            shift
            ;;
        --purge-system)
            PURGE_SYSTEM=true
            shift
            ;;
        --purge-user-cache)
            PURGE_USER_CACHE=true
            shift
            ;;
        --all-users)
            ALL_USERS=true
            shift
            ;;
        --remove-version-manager)
            [[ -n "${2:-}" ]] || die "'--remove-version-manager' requires an argument"
            VERSION_MANAGERS_TO_REMOVE+=("$2")
            shift 2
            ;;
        --remove-all-version-managers)
            REMOVE_ALL_VERSION_MANAGERS=true
            shift
            ;;
        --distro|--install-distro)
            [[ -z "$INSTALL_METHOD" || "$INSTALL_METHOD" == "distro" ]] || die "Only one install method can be specified"
            INSTALL_METHOD="distro"
            shift
            ;;
        --official)
            [[ -z "$INSTALL_METHOD" || "$INSTALL_METHOD" == "official" ]] || die "Only one install method can be specified"
            INSTALL_METHOD="official"
            shift
            ;;
        --lts)
            INSTALL_CHANNEL="lts"
            shift
            ;;
        --current|--latest)
            INSTALL_CHANNEL="current"
            shift
            ;;
        --version)
            [[ -n "${2:-}" ]] || die "'--version' requires a version argument"
            INSTALL_VERSION="$2"
            shift 2
            ;;
        --no-purge)
            NO_PURGE=true
            shift
            ;;
        --install-prefix)
            [[ -n "${2:-}" ]] || die "'--install-prefix' requires a directory"
            INSTALL_PREFIX="${2%/}"
            shift 2
            ;;
        --symlink-dir)
            [[ -n "${2:-}" ]] || die "'--symlink-dir' requires a directory"
            SYMLINK_DIR="${2%/}"
            shift 2
            ;;
        --skip-verify)
            VERIFY_DOWNLOAD=false
            shift
            ;;
        --enable-corepack)
            ENABLE_COREPACK=true
            shift
            ;;
        --skip-user-cleanup)
            log_warn "--skip-user-cleanup is no longer needed; user cleanup is opt-in"
            shift
            ;;
        -y|--yes)
            ASSUME_YES=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        -V|--version-info)
            print_version
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
        *)
            log_error "Unexpected argument: $1"
            print_usage
            exit 1
            ;;
    esac
done

validate_args
main

