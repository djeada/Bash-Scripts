#!/usr/bin/env bash

# Script Name: purge_and_reinstall_nodejs.sh
# Description: Purges existing Node.js/npm installations and optionally reinstalls
#              with support for distro packages or direct downloads from nodejs.org.
# Usage: purge_and_reinstall_nodejs.sh [options]
#
# Options:
#   --purge-only          Only purge Node.js/npm without reinstalling.
#   --distro              Install from distro package manager (apt, dnf, brew, etc.).
#   --latest              Install the latest version from nodejs.org.
#   --lts                 Install the latest LTS version from nodejs.org.
#   --version VERSION     Install a specific version (e.g., 20.10.0).
#   --skip-user-cleanup   Skip cleaning user-specific Node.js directories.
#   -d, --dry-run         Show what would be done without making changes.
#   -v, --verbose         Enable verbose output.
#   -h, --help            Display this help message.
#   -V, --version-info    Display script version.
#
# Examples:
#   purge_and_reinstall_nodejs.sh --purge-only
#   purge_and_reinstall_nodejs.sh --distro
#   purge_and_reinstall_nodejs.sh --latest --verbose
#   purge_and_reinstall_nodejs.sh --lts --dry-run
#   purge_and_reinstall_nodejs.sh --version 20.10.0

set -euo pipefail

VERSION="2.0.0"
DRY_RUN=false
VERBOSE=false
PURGE_ONLY=false
INSTALL_DISTRO=false
INSTALL_LATEST=false
INSTALL_LTS=false
INSTALL_VERSION=""
SKIP_USER_CLEANUP=false

# Detected system information
OS_TYPE=""
DISTRO=""
ARCH=""
PKG_MANAGER=""

# Function to display usage information
print_usage() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --purge-only          Only purge Node.js/npm without reinstalling."
    echo "  --distro              Install from distro package manager (apt, dnf, brew, etc.)."
    echo "  --latest              Install the latest version from nodejs.org."
    echo "  --lts                 Install the latest LTS version from nodejs.org."
    echo "  --version VERSION     Install a specific version (e.g., 20.10.0)."
    echo "  --skip-user-cleanup   Skip cleaning user-specific Node.js directories."
    echo "  -d, --dry-run         Show what would be done without making changes."
    echo "  -v, --verbose         Enable verbose output."
    echo "  -h, --help            Display this help message."
    echo "  -V, --version-info    Display script version."
    echo
    echo "Examples:"
    echo "  $0 --purge-only"
    echo "  $0 --distro"
    echo "  $0 --latest --verbose"
    echo "  $0 --lts --dry-run"
    echo "  $0 --version 20.10.0"
}

# Function to display version information
print_version() {
    echo "$0 version $VERSION"
}

# Logging function
log() {
    local message="$1"
    if [[ "$VERBOSE" == true ]]; then
        echo "[INFO] $message"
    fi
}

# Error logging function
log_error() {
    echo "[ERROR] $1" >&2
}

# Warning logging function
log_warn() {
    echo "[WARN] $1" >&2
}

# Execute or simulate command based on dry-run mode
run_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would execute: $*"
    else
        log "Executing: $*"
        "$@"
    fi
}

# Execute command with sudo or simulate based on dry-run mode
run_sudo() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would execute with sudo: $*"
    else
        log "Executing with sudo: $*"
        sudo "$@"
    fi
}

# Detect operating system type
detect_os() {
    local os_name
    os_name=$(uname -s)
    
    case "$os_name" in
        Darwin)
            OS_TYPE="macos"
            DISTRO="macOS"
            ;;
        Linux)
            OS_TYPE="linux"
            if [[ -f /etc/os-release ]]; then
                DISTRO=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')
            else
                DISTRO="unknown"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            OS_TYPE="windows"
            DISTRO="Windows"
            ;;
        *)
            OS_TYPE="unknown"
            DISTRO="unknown"
            ;;
    esac
    
    log "Detected OS: $OS_TYPE ($DISTRO)"
}

# Detect system architecture and map to Node.js naming convention
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
            log_warn "Unknown architecture: $machine_arch, using as-is"
            ;;
    esac
    
    log "Detected architecture: $ARCH"
}

# Detect package manager
detect_pkg_manager() {
    if [[ "$OS_TYPE" == "macos" ]]; then
        if command -v brew &>/dev/null; then
            PKG_MANAGER="brew"
        else
            PKG_MANAGER="none"
        fi
    elif [[ "$OS_TYPE" == "linux" ]]; then
        if command -v apt-get &>/dev/null; then
            PKG_MANAGER="apt"
        elif command -v dnf &>/dev/null; then
            PKG_MANAGER="dnf"
        elif command -v yum &>/dev/null; then
            PKG_MANAGER="yum"
        elif command -v pacman &>/dev/null; then
            PKG_MANAGER="pacman"
        elif command -v zypper &>/dev/null; then
            PKG_MANAGER="zypper"
        elif command -v apk &>/dev/null; then
            PKG_MANAGER="apk"
        else
            PKG_MANAGER="none"
        fi
    else
        PKG_MANAGER="none"
    fi
    
    log "Detected package manager: $PKG_MANAGER"
}

# Purge Node.js installed via package manager
purge_pkg_manager() {
    echo "Purging Node.js/npm via package manager ($PKG_MANAGER)..."
    
    case "$PKG_MANAGER" in
        apt)
            run_sudo apt-get purge -y nodejs npm 2>/dev/null || true
            run_sudo apt-get autoremove -y 2>/dev/null || true
            ;;
        dnf)
            run_sudo dnf remove -y nodejs npm 2>/dev/null || true
            ;;
        yum)
            run_sudo yum remove -y nodejs npm 2>/dev/null || true
            ;;
        pacman)
            run_sudo pacman -Rns --noconfirm nodejs npm 2>/dev/null || true
            ;;
        zypper)
            run_sudo zypper remove -y nodejs npm 2>/dev/null || true
            ;;
        apk)
            run_sudo apk del nodejs npm 2>/dev/null || true
            ;;
        brew)
            run_cmd brew uninstall node 2>/dev/null || true
            ;;
        none)
            log "No package manager detected, skipping package manager purge"
            ;;
    esac
}

# Purge manually installed Node.js
purge_manual_install() {
    echo "Purging manually installed Node.js/npm..."
    
    # Remove binaries found in PATH
    local node_path npm_path npx_path
    node_path=$(command -v node 2>/dev/null || true)
    npm_path=$(command -v npm 2>/dev/null || true)
    npx_path=$(command -v npx 2>/dev/null || true)
    
    for bin_path in "$node_path" "$npm_path" "$npx_path"; do
        if [[ -n "$bin_path" && -f "$bin_path" ]]; then
            log "Removing binary: $bin_path"
            run_sudo rm -f "$bin_path"
        fi
    done
    
    # Common installation directories (non-glob paths)
    local dirs_to_remove=(
        "/usr/local/lib/node_modules"
        "/usr/local/include/node"
        "/usr/local/share/doc/node"
        "/opt/nodejs"
    )
    
    for dir in "${dirs_to_remove[@]}"; do
        if [[ "$DRY_RUN" == true ]]; then
            echo "[DRY-RUN] Would remove: $dir"
        else
            sudo rm -rf "$dir" 2>/dev/null || true
        fi
    done
    
    # Glob patterns for man pages (handled separately for security)
    local man_patterns=(
        "/usr/local/share/man/man1/node.*"
        "/usr/local/share/man/man1/npm.*"
    )
    
    for pattern in "${man_patterns[@]}"; do
        if [[ "$DRY_RUN" == true ]]; then
            echo "[DRY-RUN] Would remove files matching: $pattern"
        else
            # Use find for safer glob handling
            local base_dir
            base_dir=$(dirname "$pattern")
            local file_pattern
            file_pattern=$(basename "$pattern")
            if [[ -d "$base_dir" ]]; then
                sudo find "$base_dir" -maxdepth 1 -name "$file_pattern" -exec rm -f {} \; 2>/dev/null || true
            fi
        fi
    done
}

# Clean user-specific Node.js directories
cleanup_user_dirs() {
    if [[ "$SKIP_USER_CLEANUP" == true ]]; then
        log "Skipping user directory cleanup"
        return
    fi
    
    echo "Cleaning user-specific Node.js directories..."
    
    local user_dirs_to_clean=(
        ".npm"
        ".nvm"
        ".node-gyp"
        ".node_repl_history"
        ".config/configstore/update-notifier-npm.json"
    )
    
    # Clean current user's directories
    for dir in "${user_dirs_to_clean[@]}"; do
        local full_path="$HOME/$dir"
        if [[ -e "$full_path" ]]; then
            log "Removing: $full_path"
            run_cmd rm -rf "$full_path"
        fi
    done
    
    # Clean other users' directories (requires root)
    if [[ $EUID -eq 0 ]] || [[ "$DRY_RUN" == true ]]; then
        local user_home_base=""
        
        # Determine user home directory base path based on OS
        case "$OS_TYPE" in
            macos)
                user_home_base="/Users"
                ;;
            linux)
                user_home_base="/home"
                ;;
            *)
                user_home_base="/home"
                ;;
        esac
        
        if [[ -d "$user_home_base" ]]; then
            for home_dir in "$user_home_base"/*; do
                if [[ -d "$home_dir" ]]; then
                    local username
                    username=$(basename "$home_dir")
                    log "Cleaning directories for user: $username"
                    
                    for dir in "${user_dirs_to_clean[@]}"; do
                        local full_path="$home_dir/$dir"
                        if [[ -e "$full_path" ]]; then
                            log "Removing: $full_path"
                            run_cmd rm -rf "$full_path"
                        fi
                    done
                fi
            done
        fi
    fi
}

# Fetch the latest Node.js version from nodejs.org
fetch_latest_version() {
    local version
    version=$(curl -s https://nodejs.org/dist/latest/ | grep -oE 'node-v[0-9]+\.[0-9]+\.[0-9]+' | head -1 | sed 's/node-v//')
    
    if [[ -z "$version" ]]; then
        log_error "Failed to fetch latest Node.js version"
        return 1
    fi
    
    echo "$version"
}

# Fetch the latest LTS version from nodejs.org
fetch_lts_version() {
    local version
    
    # Prefer jq if available for robust JSON parsing
    if command -v jq &>/dev/null; then
        version=$(curl -s https://nodejs.org/dist/index.json | jq -r '.[] | select(.lts != false) | .version' | head -1 | sed 's/v//')
    else
        # Fallback to grep-based parsing
        version=$(curl -s https://nodejs.org/dist/index.json | grep -oE '"version":"v[0-9]+\.[0-9]+\.[0-9]+"[^}]*"lts":"[^"]+"' | head -1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/v//')
    fi
    
    if [[ -z "$version" ]]; then
        log_error "Failed to fetch LTS Node.js version"
        return 1
    fi
    
    echo "$version"
}

# Install Node.js via package manager (distro version)
install_via_pkg_manager() {
    echo "Installing Node.js via package manager ($PKG_MANAGER)..."
    
    case "$PKG_MANAGER" in
        apt)
            run_sudo apt-get update
            run_sudo apt-get install -y nodejs npm
            ;;
        dnf)
            run_sudo dnf install -y nodejs npm
            ;;
        yum)
            run_sudo yum install -y nodejs npm
            ;;
        pacman)
            run_sudo pacman -S --noconfirm nodejs npm
            ;;
        zypper)
            run_sudo zypper install -y nodejs npm
            ;;
        apk)
            run_sudo apk add nodejs npm
            ;;
        brew)
            run_cmd brew install node
            ;;
        none)
            log_error "No supported package manager found. Cannot install via distro."
            return 1
            ;;
    esac
}

# Install Node.js from nodejs.org binary
install_from_nodejs_org() {
    local version="$1"
    local platform=""
    local archive_ext=""
    
    # Determine platform string for download URL
    case "$OS_TYPE" in
        linux)
            platform="linux"
            archive_ext="tar.xz"
            ;;
        macos)
            platform="darwin"
            archive_ext="tar.gz"
            ;;
        *)
            log_error "Unsupported OS for direct installation: $OS_TYPE"
            return 1
            ;;
    esac
    
    local filename="node-v${version}-${platform}-${ARCH}.${archive_ext}"
    local download_url="https://nodejs.org/dist/v${version}/${filename}"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    
    echo "Installing Node.js v${version} for ${platform}-${ARCH}..."
    log "Download URL: $download_url"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would download: $download_url"
        echo "[DRY-RUN] Would extract to /usr/local"
        rm -rf "$tmp_dir"
        return 0
    fi
    
    # Download
    echo "Downloading Node.js v${version}..."
    if ! curl -fsSL "$download_url" -o "$tmp_dir/$filename"; then
        log_error "Failed to download Node.js from $download_url"
        rm -rf "$tmp_dir"
        return 1
    fi
    
    # Extract
    echo "Extracting Node.js..."
    case "$archive_ext" in
        tar.xz)
            if ! sudo tar -C /usr/local --strip-components=1 -xJf "$tmp_dir/$filename"; then
                log_error "Failed to extract Node.js archive"
                rm -rf "$tmp_dir"
                return 1
            fi
            ;;
        tar.gz)
            if ! sudo tar -C /usr/local --strip-components=1 -xzf "$tmp_dir/$filename"; then
                log_error "Failed to extract Node.js archive"
                rm -rf "$tmp_dir"
                return 1
            fi
            ;;
    esac
    
    # Cleanup
    rm -rf "$tmp_dir"
    
    # Verify installation
    echo "Verifying installation..."
    if command -v node &>/dev/null; then
        echo "Node.js $(node --version) installed successfully"
    else
        log_warn "Node.js binary not found in PATH. You may need to add /usr/local/bin to your PATH."
    fi
    
    if command -v npm &>/dev/null; then
        echo "npm $(npm --version) installed successfully"
    fi
}

# Main execution
main() {
    # Detect system information
    detect_os
    detect_arch
    detect_pkg_manager
    
    echo "System: $OS_TYPE ($DISTRO) on $ARCH"
    echo "Package manager: $PKG_MANAGER"
    echo
    
    # Purge existing installations
    echo "=== Purging existing Node.js/npm installations ==="
    purge_pkg_manager
    purge_manual_install
    cleanup_user_dirs
    echo "Purge completed."
    echo
    
    # Exit if purge-only mode
    if [[ "$PURGE_ONLY" == true ]]; then
        echo "Purge-only mode: Skipping installation."
        return 0
    fi
    
    # Install based on selected method
    echo "=== Installing Node.js/npm ==="
    
    if [[ "$INSTALL_DISTRO" == true ]]; then
        install_via_pkg_manager
    elif [[ "$INSTALL_LATEST" == true ]]; then
        local latest_version
        latest_version=$(fetch_latest_version)
        if [[ -n "$latest_version" ]]; then
            echo "Latest version: v$latest_version"
            install_from_nodejs_org "$latest_version"
        fi
    elif [[ "$INSTALL_LTS" == true ]]; then
        local lts_version
        lts_version=$(fetch_lts_version)
        if [[ -n "$lts_version" ]]; then
            echo "Latest LTS version: v$lts_version"
            install_from_nodejs_org "$lts_version"
        fi
    elif [[ -n "$INSTALL_VERSION" ]]; then
        echo "Installing specified version: v$INSTALL_VERSION"
        install_from_nodejs_org "$INSTALL_VERSION"
    else
        # Default: install latest from nodejs.org
        local latest_version
        latest_version=$(fetch_latest_version)
        if [[ -n "$latest_version" ]]; then
            echo "Installing latest version: v$latest_version"
            install_from_nodejs_org "$latest_version"
        fi
    fi
    
    echo
    echo "Node.js installation completed."
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --purge-only)
            PURGE_ONLY=true
            shift
            ;;
        --distro)
            INSTALL_DISTRO=true
            shift
            ;;
        --latest)
            INSTALL_LATEST=true
            shift
            ;;
        --lts)
            INSTALL_LTS=true
            shift
            ;;
        --version)
            if [[ -n "${2:-}" ]]; then
                INSTALL_VERSION="$2"
                shift 2
            else
                log_error "'--version' requires a version argument."
                exit 1
            fi
            ;;
        --skip-user-cleanup)
            SKIP_USER_CLEANUP=true
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

# Validate mutually exclusive options
install_options=0
if [[ "$INSTALL_DISTRO" == true ]]; then
    install_options=$((install_options + 1))
fi
if [[ "$INSTALL_LATEST" == true ]]; then
    install_options=$((install_options + 1))
fi
if [[ "$INSTALL_LTS" == true ]]; then
    install_options=$((install_options + 1))
fi
if [[ -n "$INSTALL_VERSION" ]]; then
    install_options=$((install_options + 1))
fi

if [[ $install_options -gt 1 ]]; then
    log_error "Only one of --distro, --latest, --lts, or --version can be specified."
    exit 1
fi

main

