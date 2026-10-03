#!/usr/bin/env bash

# Script Name: empty_trash.sh
# Description: Safely empties the trash directory with various options and features.
# Usage: empty_trash.sh [options]
# Options:
#   -p, --path PATH            Specify trash directory path(s). Can be specified multiple times.
#   -l, --log-file FILE        Enable logging to a specified log file.
#   -v, --verbose              Enable verbose mode.
#   -f, --force                Force deletion without confirmation.
#   -s, --simulate             Simulate deletion (dry-run, no confirmation needed).
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
    echo "  -s, --simulate             Simulate deletion (dry-run, no confirmation needed)."
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

# Print an error message and exit
die() {
    echo "Error: $*" >&2
    exit 1
}

# Function to confirm deletion
confirm_deletion() {
    if [[ "$FORCE" == true || "$SIMULATE" == true ]]; then
        return 0
    fi
    printf 'Trash directories to empty:\n' >&2
    printf '  %s\n' "${TRASH_PATHS[@]}" >&2
    read -p "Are you sure you want to empty the trash? [y/N] " -n 1 -r || return 1
    echo
    [[ "$REPLY" =~ ^[Yy]$ ]]
}

# Function to get trash directories for a user
get_trash_paths_for_user() {
    local user="$1"
    local home_dir=""

    # Look up the home directory without eval (user names are untrusted input)
    if command -v getent >/dev/null 2>&1; then
        home_dir=$(getent passwd "$user" | cut -d: -f6)
    elif [[ "$(uname)" == "Darwin" ]]; then
        home_dir=$(dscl . -read "/Users/$user" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
    fi
    if [[ -z "$home_dir" ]]; then
        echo "Warning: cannot determine home directory of user '$user'; skipping." >&2
        return 0
    fi

    # Print one path per line (the caller reads them with mapfile)
    case "$(uname)" in
        Darwin)
            echo "$home_dir/.Trash"
            ;;
        Linux)
            # FreeDesktop trash: deleted files plus their .trashinfo metadata
            echo "$home_dir/.local/share/Trash/files"
            echo "$home_dir/.local/share/Trash/info"
            ;;
    esac
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

        # Resolve symlinks and things like '//' or '/.' before the root check
        local resolved
        resolved=$(cd "$path" && pwd -P) || continue
        if [[ "$resolved" == "/" ]] && [[ "$NO_PRESERVE_ROOT" != true ]]; then
            log_action "Refusing to delete '/' without --no-preserve-root option."
            continue
        fi

        if [[ "$SIMULATE" == true ]]; then
            log_action "Simulating emptying trash at '$path'."
            find "$path" -mindepth 1 -print || true
        else
            log_action "Emptying trash at '$path'."
            local deleted_files
            # find -delete exits non-zero if some items could not be removed;
            # report that, but keep going with the other trash directories.
            deleted_files=$( { find "$path" -mindepth 1 -print -delete || echo "Warning: some items in '$path' could not be deleted." >&2; } | wc -l)
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
        -p|--path)
            if [[ -n "${2-}" ]]; then
                TRASH_PATHS+=("$2")
                shift 2
            else
                die "'--path' requires a non-empty argument."
            fi
            ;;
        -l|--log-file)
            if [[ -n "${2-}" ]]; then
                LOG_FILE="$2"
                LOG_ENABLED=true
                shift 2
            else
                die "'--log-file' requires a non-empty argument."
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
            if [[ -n "${2-}" ]]; then
                USERS+=("$2")
                shift 2
            else
                die "'--user' requires a non-empty argument."
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
            echo "Unknown option: $1" >&2
            print_usage >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

if [[ $# -gt 0 ]]; then
    echo "Unexpected argument: $1 (use -p to specify a trash path)" >&2
    print_usage >&2
    exit 1
fi

# Verify root privileges if necessary
if [[ "$ALL_USERS" == true ]] || [[ "${#USERS[@]}" -gt 0 ]]; then
    if [[ "$EUID" -ne 0 ]]; then
        die "This option requires root privileges. Please run as root."
    fi
fi

# Build list of trash paths
if [[ "${#TRASH_PATHS[@]}" -eq 0 ]]; then
    if [[ "$ALL_USERS" == true ]]; then
        # Get all users
        mapfile -t USERS < <(awk -F: '{ if ($3 >= 1000 && $3 != 65534) print $1}' /etc/passwd)
    elif [[ "${#USERS[@]}" -eq 0 ]]; then
        # Default to current user
        USERS+=("$(id -un)")
    fi

    for user in "${USERS[@]}"; do
        mapfile -t user_trash_paths < <(get_trash_paths_for_user "$user")
        TRASH_PATHS+=("${user_trash_paths[@]}")
    done
fi

if [[ "${#TRASH_PATHS[@]}" -eq 0 ]]; then
    die "No trash paths specified and none found for users."
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

