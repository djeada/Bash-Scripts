#!/usr/bin/env bash

# Script Name: purge_pip.sh
# Description: Safely uninstalls the Python packages installed for the current 'pip',
#              keeping essential packaging tools (pip, setuptools, wheel) intact.
#              Before uninstalling, the full 'pip freeze' list is saved to
#              ~/python_package_backups/backup_<timestamp>.txt (reinstall with 'pip install -r').
# Usage: purge_pip.sh [options]
#
# Options:
#   -e, --exclude PACKAGE(S)    Exclude additional packages from uninstallation (comma-separated).
#   -i, --include PACKAGE(S)    Only uninstall these packages (comma-separated).
#   -a, --all                   Uninstall all packages including essential ones.
#   -d, --dry-run               Show what would be uninstalled without making changes.
#   -l, --log-file FILE         Log actions to a specified file.
#   -v, --verbose               Enable verbose output.
#   -h, --help                  Display this help message.
#   -V, --version               Display script version.
#
# Examples:
#   purge_pip.sh --exclude numpy,requests
#   purge_pip.sh --dry-run --verbose
#   purge_pip.sh --include pandas,matplotlib

set -euo pipefail

VERSION="1.0.0"
LOG_FILE=""
LOG_ENABLED=false
VERBOSE=false
DRY_RUN=false
UNINSTALL_ALL=false
EXCLUDE_PACKAGES=()
INCLUDE_PACKAGES=()

# Essential packages to keep
ESSENTIAL_PACKAGES=("pip" "setuptools" "wheel")

# Function to display usage information
print_usage() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -e, --exclude PACKAGE(S)    Exclude additional packages from uninstallation (comma-separated)."
    echo "  -i, --include PACKAGE(S)    Only uninstall these packages (comma-separated)."
    echo "  -a, --all                   Uninstall all packages including essential ones."
    echo "  -d, --dry-run               Show what would be uninstalled without making changes."
    echo "  -l, --log-file FILE         Log actions to a specified file."
    echo "  -v, --verbose               Enable verbose output."
    echo "  -h, --help                  Display this help message."
    echo "  -V, --version               Display script version."
    echo
    echo "Examples:"
    echo "  $0 --exclude numpy,requests"
    echo "  $0 --dry-run --verbose"
    echo "  $0 --include pandas,matplotlib"
}

# Function to display version information
print_version() {
    echo "$0 version $VERSION"
}

# Function for logging
log_action() {
    local message="$1"
    if [[ "$LOG_ENABLED" == true ]]; then
        echo "$(date +"%Y-%m-%d %T"): $message" >> "$LOG_FILE"
    fi
    if [[ "$VERBOSE" == true ]]; then
        echo "$message"
    fi
}

# Function to confirm uninstallation
confirm_uninstallation() {
    read -p "Are you sure you want to proceed with the uninstallation? [y/N] " -n 1 -r
    echo
    [[ "$REPLY" =~ ^[Yy]$ ]]
}

# Normalize a package name for comparison (PEP 503: case-insensitive, -_. equivalent)
normalize_name() {
    echo "$1" | tr '[:upper:]_.' '[:lower:]--'
}

# Function to uninstall packages
uninstall_packages() {
    local packages=("$@")
    local backup_dir="$HOME/python_package_backups"
    local timestamp
    timestamp=$(date +%Y%m%d%H%M%S)
    local backup_file="$backup_dir/backup_$timestamp.txt"
    local failed=0

    if [[ "$DRY_RUN" == true ]]; then
        for package in "${packages[@]}"; do
            echo "Would uninstall: $package"
        done
        return 0
    fi

    # Save name==version pins of everything installed so the state can be restored
    mkdir -p "$backup_dir"
    pip freeze --all > "$backup_file"
    log_action "Backup of installed packages created at $backup_file"

    for package in "${packages[@]}"; do
        log_action "Uninstalling package: $package"
        if pip uninstall -y "$package"; then
            log_action "Successfully uninstalled: $package"
        else
            log_action "Error: Failed to uninstall $package"
            echo "Error: Failed to uninstall $package" >&2
            failed=1
        fi
    done

    return "$failed"
}

# Check for pip
if ! command -v pip &>/dev/null; then
    echo "Error: 'pip' is not installed." >&2
    exit 1
fi

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--exclude)
            if [[ -n "${2-}" ]]; then
                IFS=',' read -ra EXCLUDE_PACKAGES <<< "$2"
                shift 2
            else
                echo "Error: '--exclude' requires a non-empty argument." >&2
                exit 1
            fi
            ;;
        -i|--include)
            if [[ -n "${2-}" ]]; then
                IFS=',' read -ra INCLUDE_PACKAGES <<< "$2"
                shift 2
            else
                echo "Error: '--include' requires a non-empty argument." >&2
                exit 1
            fi
            ;;
        -a|--all)
            UNINSTALL_ALL=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -l|--log-file)
            if [[ -n "${2-}" ]]; then
                LOG_FILE="$2"
                LOG_ENABLED=true
                shift 2
            else
                echo "Error: '--log-file' requires a non-empty argument." >&2
                exit 1
            fi
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        -V|--version)
            print_version
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            print_usage >&2
            exit 1
            ;;
    esac
done

# Candidate packages: the --include list, or everything installed
# ('pip list --format=freeze' also lists pip/setuptools/wheel, unlike 'pip freeze')
if [[ "${#INCLUDE_PACKAGES[@]}" -gt 0 ]]; then
    CANDIDATES=("${INCLUDE_PACKAGES[@]}")
else
    mapfile -t CANDIDATES < <(pip list --format=freeze | cut -d'=' -f1)
fi

# Packages that must be kept: user exclusions, plus essential ones unless --all
KEEP=("${EXCLUDE_PACKAGES[@]}")
if [[ "$UNINSTALL_ALL" == false ]]; then
    KEEP+=("${ESSENTIAL_PACKAGES[@]}")
fi

INSTALLED_PACKAGES=()
for pkg in "${CANDIDATES[@]}"; do
    [[ -z "$pkg" ]] && continue
    skip=false
    for keep in "${KEEP[@]}"; do
        if [[ "$(normalize_name "$pkg")" == "$(normalize_name "$keep")" ]]; then
            skip=true
            break
        fi
    done
    if [[ $skip == false ]]; then
        INSTALLED_PACKAGES+=("$pkg")
    fi
done

if [[ "${#INSTALLED_PACKAGES[@]}" -eq 0 ]]; then
    echo "No packages to uninstall."
    exit 0
fi

echo "The following packages will be uninstalled:"
for pkg in "${INSTALLED_PACKAGES[@]}"; do
    echo "- $pkg"
done

if [[ "$DRY_RUN" == false ]] && ! confirm_uninstallation; then
    echo "Uninstallation cancelled."
    exit 0
fi

if ! uninstall_packages "${INSTALLED_PACKAGES[@]}"; then
    log_action "Package uninstallation completed with errors."
    echo "Package uninstallation completed with errors." >&2
    exit 1
fi

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: no packages were uninstalled."
    exit 0
fi

log_action "Package uninstallation completed."
echo "Package uninstallation completed."

