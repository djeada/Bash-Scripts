#!/usr/bin/env bash

# Script Name: clear_cache.sh
# Description: Clears local caches in specified cache directories with advanced options.
# Usage: clear_cache.sh [options]
#
# Options:
#   -d, --directory DIR      Specify cache directory (default: ~/.cache of the current user). Can be specified multiple times.
#   -a, --age DAYS           Delete files older than DAYS days (default: 0, meaning all files).
#   -l, --log-file FILE      Enable logging to specified log file.
#   -v, --verbose            Enable verbose output.
#   -f, --force              Force deletion without confirmation.
#   -s, --simulate           Perform a dry run without deleting files.
#   -u, --user USER          Clear cache for specified user(s). Requires root privileges.
#   -A, --all-users          Clear cache for all users. Requires root privileges.
#       --system             Clear system cache directories.
#   -h, --help               Display this help message.
#
# Examples:
#   clear_cache.sh --age 14 -d ~/.cache
#   clear_cache.sh --all-users --force
#   clear_cache.sh --simulate --verbose

set -euo pipefail

# Default configurations
LOG_FILE="/var/log/clear_cache.log"
LOG_ENABLED=false
VERBOSE=false
FORCE=false
SIMULATE=false
AGE=0
CACHE_DIRS=()
USERS=()
ALL_USERS=false
SYSTEM_CACHE=false

# Function to display usage information
print_usage() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -d, --directory DIR      Specify cache directory (default: ~/.cache of the current user). Can be specified multiple times."
    echo "  -a, --age DAYS           Delete files older than DAYS days (default: 0, meaning all files)."
    echo "  -l, --log-file FILE      Enable logging to specified log file."
    echo "  -v, --verbose            Enable verbose output."
    echo "  -f, --force              Force deletion without confirmation."
    echo "  -s, --simulate           Perform a dry run without deleting files."
    echo "  -u, --user USER          Clear cache for specified user(s). Requires root privileges."
    echo "  -A, --all-users          Clear cache for all users. Requires root privileges."
    echo "      --system             Clear system cache directories."
    echo "  -h, --help               Display this help message."
    echo
    echo "Examples:"
    echo "  $0 --age 14 -d ~/.cache"
    echo "  $0 --all-users --force"
    echo "  $0 --simulate --verbose"
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

# Function to confirm deletion
confirm_deletion() {
    if [[ "$FORCE" == true ]]; then
        return 0
    fi
    local reply=""
    echo "Files will be deleted from:"
    printf '  %s\n' "$@"
    read -r -p "Are you sure you want to delete these files? [y/N] " -n 1 reply || true
    echo
    [[ "$reply" =~ ^[Yy]$ ]]
}

# Function to get cache directories for a user
get_cache_dirs_for_user() {
    local user="$1"
    local home_dir
    home_dir=$(getent passwd "$user" | cut -d: -f6)
    if [[ -z "$home_dir" ]]; then
        echo "Warning: user '$user' not found, skipping." >&2
        return 0
    fi
    echo "$home_dir/.cache"
}

# Function to clear cache directories
clear_cache() {
    local paths=("$@")
    local total_deleted=0
    # With an age of 0 every file is deleted; otherwise only files modified
    # more than AGE days ago (-mmin avoids -mtime's whole-day rounding).
    local age_filter=()
    if [[ "$AGE" -gt 0 ]]; then
        age_filter=(-mmin +"$((AGE * 1440))")
    fi

    for path in "${paths[@]}"; do
        if [[ ! -d "$path" ]]; then
            log_action "Cache directory '$path' does not exist."
            continue
        fi

        if [[ ! -w "$path" ]]; then
            log_action "No write permission for cache directory '$path'."
            continue
        fi

        if [[ "$SIMULATE" == true ]]; then
            log_action "Simulating clearing cache at '$path'."
            find "$path" -type f "${age_filter[@]}" || true
        else
            log_action "Clearing cache at '$path'."
            local deleted_files
            if ! deleted_files=$(find "$path" -type f "${age_filter[@]}" -print -delete | wc -l); then
                echo "Warning: some files in '$path' could not be deleted." >&2
            fi
            total_deleted=$((total_deleted + deleted_files))
            log_action "Deleted $deleted_files items from '$path'."
        fi
    done

    if [[ "$SIMULATE" != true ]]; then
        log_action "Total items deleted: $total_deleted."
    else
        log_action "Simulation complete."
    fi
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--directory)
            if [[ -n "${2:-}" ]]; then
                CACHE_DIRS+=("$2")
                shift 2
            else
                echo "Error: '--directory' requires a non-empty argument." >&2
                exit 1
            fi
            ;;
        -a|--age)
            if [[ -n "${2:-}" ]]; then
                AGE="$2"
                shift 2
            else
                echo "Error: '--age' requires a non-empty argument." >&2
                exit 1
            fi
            ;;
        -l|--log-file)
            if [[ -n "${2:-}" ]]; then
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
        -f|--force)
            FORCE=true
            shift
            ;;
        -s|--simulate)
            SIMULATE=true
            shift
            ;;
        -u|--user)
            if [[ -n "${2:-}" ]]; then
                USERS+=("$2")
                shift 2
            else
                echo "Error: '--user' requires a non-empty argument." >&2
                exit 1
            fi
            ;;
        -A|--all-users)
            ALL_USERS=true
            shift
            ;;
        --system)
            SYSTEM_CACHE=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Unknown option: $1" >&2
            print_usage >&2
            exit 1
            ;;
        *)
            echo "Unexpected argument: $1" >&2
            print_usage >&2
            exit 1
            ;;
    esac
done

if [[ $# -gt 0 ]]; then
    echo "Unexpected argument: $1" >&2
    exit 1
fi

if ! [[ "$AGE" =~ ^[0-9]+$ ]]; then
    echo "Error: '--age' must be a non-negative integer." >&2
    exit 1
fi

# Verify root privileges if necessary
if [[ "$ALL_USERS" == true ]] || [[ "${#USERS[@]}" -gt 0 ]]; then
    if [[ "$EUID" -ne 0 ]]; then
        echo "This option requires root privileges. Please run as root." >&2
        exit 1
    fi
fi

# Build list of cache directories: explicit directories plus the caches of
# the selected users (the current user when neither -d nor -u/-A is given)
if [[ "$ALL_USERS" == true ]]; then
    # Get all users
    mapfile -t USERS < <(awk -F: '{ if ($3 >= 1000 && $3 != 65534) print $1}' /etc/passwd)
elif [[ "${#USERS[@]}" -eq 0 && "${#CACHE_DIRS[@]}" -eq 0 ]]; then
    # Default to current user
    USERS+=("$(id -un)")
fi

for user in "${USERS[@]}"; do
    user_cache_dir=$(get_cache_dirs_for_user "$user")
    if [[ -n "$user_cache_dir" ]]; then
        CACHE_DIRS+=("$user_cache_dir")
    fi
done

if [[ "$SYSTEM_CACHE" == true ]]; then
    if [[ "$(uname)" == "Linux" ]]; then
        CACHE_DIRS+=("/var/cache")
    elif [[ "$(uname)" == "Darwin" ]]; then
        CACHE_DIRS+=("/Library/Caches")
    else
        echo "Unsupported system. Cannot determine system cache directories." >&2
    fi
fi

if [[ "${#CACHE_DIRS[@]}" -eq 0 ]]; then
    echo "No cache directories specified and none found for users." >&2
    exit 1
fi

# Confirm deletion (a simulation deletes nothing, so it needs no confirmation)
if [[ "$SIMULATE" != true ]] && ! confirm_deletion "${CACHE_DIRS[@]}"; then
    echo "Cache clearing cancelled."
    log_action "Cache clearing cancelled by user."
    exit 0
fi

# Clear the cache directories
clear_cache "${CACHE_DIRS[@]}"

log_action "Cache clearing completed."

