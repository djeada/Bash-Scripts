#!/usr/bin/env bash

# Script Name: uninstall_python_packages.sh
# Description: Safely uninstalls user-installed Python packages, keeping essential system packages intact.
# Usage: uninstall_python_packages.sh [options]
#
# Options:
#   -e, --exclude PACKAGE(S)    Exclude additional packages from uninstallation (comma-separated).
#   -i, --include PACKAGE(S)    Include specific packages for uninstallation (comma-separated).
#   -a, --all                   Uninstall all packages including essential ones.
#   -d, --dry-run               Show what would be uninstalled without making changes.
#   -l, --log-file FILE         Log actions to a specified file.
#   -v, --verbose               Enable verbose output.
#   -h, --help                  Display this help message.
#   -V, --version               Display script version.
#
# Examples:
#   uninstall_python_packages.sh --exclude numpy,requests
#   uninstall_python_packages.sh --dry-run --verbose
#   uninstall_python_packages.sh --include pandas,matplotlib

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
    echo "  -i, --include PACKAGE(S)    Include specific packages for uninstallation (comma-separated)."
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

# Function to uninstall packages
uninstall_packages() {
    local packages=("$@")
    local backup_dir="$HOME/python_package_backups"
    local timestamp
    timestamp=$(date +%Y%m%d%H%M%S)
    local backup_file="$backup_dir/backup_$timestamp.txt"

    mkdir -p "$backup_dir"
    echo "${packages[@]}" > "$backup_file"
    log_action "Backup of uninstalled packages created at $backup_file"

    for package in "${packages[@]}"; do
        log_action "Uninstalling package: $package"
        if [[ "$DRY_RUN" == true ]]; then
            echo "Would uninstall: $package"
        else
            if pip uninstall -y "$package"; then
                log_action "Successfully uninstalled: $package"
            else
                log_action "Error: Failed to uninstall $package"
            fi
        fi
    done
}

# Check for pip
if ! command -v pip &>/dev/null; then
    echo "Error: 'pip' is not installed."
    exit 1
fi

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--exclude)
            if [[ -n "$2" ]]; then
                IFS=',' read -ra EXCLUDE_PACKAGES <<< "$2"
                shift 2
            else
                echo "Error: '--exclude' requires a non-empty argument."
                exit 1
            fi
            ;;
        -i|--include)
            if [[ -n "$2" ]]; then
                IFS=',' read -ra INCLUDE_PACKAGES <<< "$2"
                shift 2
            else
                echo "Error: '--include' requires a non-empty argument."
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
            if [[ -n "$2" ]]; then
                LOG_FILE="$2"
                LOG_ENABLED=true
                shift 2
            else
                echo "Error: '--log-file' requires a non-empty argument."
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
        -*)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
        *)
            # No more options
            break
            ;;
    esac
done

# Get list of installed packages
if [[ "$UNINSTALL_ALL" == true ]]; then
    mapfile -t INSTALLED_PACKAGES < <(pip freeze | cut -d'=' -f1)
else
    mapfile -t INSTALLED_PACKAGES < <(pip freeze | cut -d'=' -f1 | grep -vE "^($(IFS="|"; echo "${ESSENTIAL_PACKAGES[*]}"))$")
fi

# Exclude specified packages
if [[ "${#EXCLUDE_PACKAGES[@]}" -gt 0 ]]; then
    for exclude in "${EXCLUDE_PACKAGES[@]}"; do
        # Removed problematic array manipulation line
        :
    done
fi

# If include packages are specified, only uninstall those
if [[ "${#INCLUDE_PACKAGES[@]}" -gt 0 ]]; then
    INSTALLED_PACKAGES=("${INCLUDE_PACKAGES[@]}")
fi

# Remove ARGS if not used

# Refactor array filtering to use a robust method
filtered_packages=()
for pkg in "${INSTALLED_PACKAGES[@]}"; do
    skip=false
    for exclude in "${ESSENTIAL_PACKAGES[@]}" "${EXCLUDE_PACKAGES[@]}"; do
        if [[ $pkg == "$exclude" ]]; then
            skip=true
            break
        fi
    done
    if [[ $skip == false ]]; then
        filtered_packages+=("$pkg")
    fi

done
INSTALLED_PACKAGES=("${filtered_packages[@]}")

if [[ "${#INSTALLED_PACKAGES[@]}" -eq 0 ]]; then
    echo "No packages to uninstall."
    exit 0
fi

echo "The following packages will be uninstalled:"
for pkg in "${INSTALLED_PACKAGES[@]}"; do
    echo "- $pkg"
done

if ! confirm_uninstallation; then
    echo "Uninstallation cancelled."
    exit 0
fi

uninstall_packages "${INSTALLED_PACKAGES[@]}"

log_action "Package uninstallation completed."
echo "Package uninstallation completed."

