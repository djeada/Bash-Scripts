#!/usr/bin/env bash

# Script Name: empty_trash.sh
# Description: Safely empties the trash directory with various options and features.
# Usage: empty_trash.sh [options]
# Options:
#   -p, --path PATH            Specify trash directory path(s). Can be specified multiple times.
#   -l, --log-file FILE        Enable logging to a specified log file.
#   -v, --verbose              Enable verbose mode.
#   -f, --force                Force deletion without confirmation.
#   -s, --simulate             Simulate deletion (dry-run).
#   -u, --user USER            Empty trash for specified user(s). Requires root privileges.
#   -a, --all-users            Empty trash for all users. Requires root privileges.
#       --no-preserve-root     Allow deleting root directory (dangerous).
#   -h, --help                 Display this help message.
# Examples:
#   empty_trash.sh -p ~/.Trash
#   empty_trash.sh --all-users --force
#   empty_trash.sh -v -s

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# Default configurations
LOG_FILE="/var/log/empty_trash.log"
LOG_ENABLED=false
VERBOSE=false
FORCE=false
SIMULATE=false
TRASH_PATHS=()
USERS=()
ALL_USERS=false
NO_PRESERVE_ROOT=false

# Function to display usage information
print_usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -p, --path PATH            Specify trash directory path(s). Can be specified multiple times."
    echo "  -l, --log-file FILE        Enable logging to a specified log file."
    echo "  -v, --verbose              Enable verbose mode."
    echo "  -f, --force                Force deletion without confirmation."
    echo "  -s, --simulate             Simulate deletion (dry-run)."
    echo "  -u, --user USER            Empty trash for specified user(s). Requires root privileges."
    echo "  -a, --all-users            Empty trash for all users. Requires root privileges."
    echo "      --no-preserve-root     Allow deleting root directory (dangerous)."
    echo "  -h, --help                 Display this help message."
    echo "Examples:"
    echo "  $0 -p ~/.Trash"
    echo "  $0 --all-users --force"
    echo "  $0 -v -s"
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
    read -p "Are you sure you want to empty the trash? [y/N] " -n 1 -r
    echo
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to get trash directories for a user
get_trash_paths_for_user() {
    local user="$1"
    local home_dir
    home_dir=$(eval echo "~$user")
    local trash_paths=()

    # Detect OS and set trash path accordingly
    if [[ "$(uname)" == "Darwin" ]]; then
        trash_paths+=("$home_dir/.Trash")
    elif [[ "$(uname)" == "Linux" ]]; then
        trash_paths+=("$home_dir/.local/share/Trash/files")
    else
        echo "Unsupported system. Please specify the trash path."
        exit 1
    fi

    echo "${trash_paths[@]}"
}

# Function to empty trash directories
empty_trash() {
    local paths=("$@")
    local total_deleted=0
    for path in "${paths[@]}"; do
        if [[ ! -d "$path" ]]; then
            log_action "Trash directory '$path' does not exist."
            continue
        fi

        if [[ ! -w "$path" ]]; then
            log_action "No write permission for trash directory '$path'."
            continue
        fi

        if [[ "$path" == "/" ]] && [[ "$NO_PRESERVE_ROOT" != true ]]; then
            log_action "Refusing to delete '/' without --no-preserve-root option."
            continue
        fi

        if [[ "$SIMULATE" == true ]]; then
            log_action "Simulating emptying trash at '$path'."
            find "$path" -mindepth 1 -print
        else
            log_action "Emptying trash at '$path'."
            local deleted_files
            deleted_files=$(find "$path" -mindepth 1 -print -delete | wc -l)
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
ARGS=("$@")
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--path)
            if [[ -n "$2" ]]; then
                TRASH_PATHS+=("$2")
                shift 2
            else
                echo "Error: '--path' requires a non-empty argument."
                exit 1
            fi
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
        -f|--force)
            FORCE=true
            shift
            ;;
        -s|--simulate)
            SIMULATE=true
            shift
            ;;
        -u|--user)
            if [[ -n "$2" ]]; then
                USERS+=("$2")
                shift 2
            else
                echo "Error: '--user' requires a non-empty argument."
                exit 1
            fi
            ;;
        -a|--all-users)
            ALL_USERS=true
            shift
            ;;
        --no-preserve-root)
            NO_PRESERVE_ROOT=true
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
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
        *)
            # No more options, break
            break
            ;;
    esac
done

# Verify root privileges if necessary
if [[ "$ALL_USERS" == true ]] || [[ "${#USERS[@]}" -gt 0 ]]; then
    if [[ "$EUID" -ne 0 ]]; then
        echo "This option requires root privileges. Please run as root."
        exit 1
    fi
fi

# Build list of trash paths
if [[ "${#TRASH_PATHS[@]}" -eq 0 ]]; then
    if [[ "$ALL_USERS" == true ]]; then
        # Get all users
        mapfile -t USERS < <(awk -F: '{ if ($3 >= 1000 && $3 != 65534) print $1}' /etc/passwd)
    elif [[ "${#USERS[@]}" -eq 0 ]]; then
        # Default to current user
        USERS+=("$USER")
    fi

    for user in "${USERS[@]}"; do
        mapfile -t user_trash_paths < <(get_trash_paths_for_user "$user")
        TRASH_PATHS+=("${user_trash_paths[@]}")
    done
fi

if [[ "${#TRASH_PATHS[@]}" -eq 0 ]]; then
    echo "No trash paths specified and none found for users."
    exit 1
fi

# Confirm deletion
if ! confirm_deletion; then
    echo "Trash emptying cancelled."
    log_action "Trash emptying cancelled by user."
    exit 0
fi

# Empty the trash directories
empty_trash "${TRASH_PATHS[@]}"

log_action "Trash emptying completed."
