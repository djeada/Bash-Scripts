#!/usr/bin/env bash

# Script Name: web_block.sh
# Description: Block or unblock websites by modifying the hosts file, with advanced options and features.
#
# Usage: sudo ./web_block.sh [options] domain1 [domain2 ... domainN]
#
# Options:
#   -h, --help            Display this help message and exit.
#   -a, --add             Block the specified domain(s).
#   -r, --remove          Unblock the specified domain(s).
#   -l, --list            List all currently blocked domains.
#   -b, --backup FILE     Specify a backup file for the hosts file (default: '/etc/hosts.bak').
#   -d, --dry-run         Show what would be done without making changes.
#   -L, --log FILE        Enable logging to the specified file (default: '/var/log/web_block.log').
#   -f, --force           Force the operation without prompting for confirmation.
#   -V, --verbose         Enable verbose output.
#   -c, --config FILE     Specify a configuration file.
#   -H, --hosts FILE      Specify a custom hosts file (default: '/etc/hosts').
#
# Examples:
#   sudo ./web_block.sh --add example.com
#   sudo ./web_block.sh --remove example.com --verbose
#   sudo ./web_block.sh --list
#   sudo ./web_block.sh --add example.com example.org --force
#   sudo ./web_block.sh --config myconfig.conf --add example.com

set -euo pipefail

# Default configurations
HOSTS_FILE="/etc/hosts"
BACKUP_FILE="/etc/hosts.bak"
LOG_FILE="/var/log/web_block.log"
LOG_ENABLED=false
DRY_RUN=false
FORCE=false
VERBOSE=false
OPERATION=""
DOMAINS=()
CONFIG_FILE=""

function show_help {
    grep '^#' "$0" | cut -c 4-
    exit 0
}

function log_action {
    if [ "$LOG_ENABLED" = true ]; then
        echo "$(date +"%Y-%m-%d %T"): $1" >> "$LOG_FILE"
    fi
}

function validate_domain {
    local domain="$1"
    local domain_regex='^([a-zA-Z0-9](-?[a-zA-Z0-9])*\.)+[a-zA-Z]{2,}$'
    if ! [[ $domain =~ $domain_regex ]]; then
        echo "Error: Invalid domain name '$domain'."
        exit 1
    fi
}

function backup_hosts {
    if [ "$DRY_RUN" = false ]; then
        cp "$HOSTS_FILE" "$BACKUP_FILE"
        [ "$VERBOSE" = true ] && echo "Backup of '$HOSTS_FILE' created at '$BACKUP_FILE'."
    else
        [ "$VERBOSE" = true ] && echo "[Dry Run] Would create backup of '$HOSTS_FILE' at '$BACKUP_FILE'."
    fi
}

function modify_hosts {
    local action="$1"
    shift
    local domains=("$@")

    local action_msg=""
    local entry=""
    local hosts_content=""
    hosts_content=$(cat "$HOSTS_FILE")

    for domain in "${domains[@]}"; do
        validate_domain "$domain"
        entry="127.0.0.1 $domain"
        case "$action" in
            add)
                if grep -qF "$entry" <<< "$hosts_content"; then
                    action_msg="Domain '$domain' is already blocked."
                else
                    if [ "$DRY_RUN" = false ]; then
                        echo "$entry" >> "$HOSTS_FILE"
                        action_msg="Blocked domain '$domain'."
                    else
                        action_msg="[Dry Run] Would block domain '$domain'."
                    fi
                fi
                ;;
            remove)
                if grep -qF "$entry" <<< "$hosts_content"; then
                    if [ "$DRY_RUN" = false ]; then
                        sed -i.bak "/^127\.0\.0\.1 $domain$/d" "$HOSTS_FILE"
                        action_msg="Unblocked domain '$domain'."
                    else
                        action_msg="[Dry Run] Would unblock domain '$domain'."
                    fi
                else
                    action_msg="Domain '$domain' is not currently blocked."
                fi
                ;;
            *)
                echo "Error: Invalid operation."
                exit 1
                ;;
        esac

        echo "$action_msg"
        log_action "$action_msg"
    done
}

function list_blocked_domains {
    echo "Currently blocked domains:"
    grep "^127\.0\.0\.1" "$HOSTS_FILE" | awk '{print $2}'
}

function confirm_operation {
    if [[ "$FORCE" = false ]]; then
        read -r -p "Are you sure you want to proceed? (y/n): " response
        if [[ "$response" != "y" ]]; then
            echo "Operation cancelled."
            exit 0
        fi
    fi
}

function parse_config_file {
    if [ -f "$CONFIG_FILE" ]; then
        [ "$VERBOSE" = true ] && echo "Loading configuration from '$CONFIG_FILE'..."
        while IFS='=' read -r key value; do
            case "$key" in
                hosts_file) HOSTS_FILE="$value" ;;
                backup_file) BACKUP_FILE="$value" ;;
                log_file) LOG_FILE="$value" ;;
                log_enabled) LOG_ENABLED="$value" ;;
                dry_run) DRY_RUN="$value" ;;
                force) FORCE="$value" ;;
                verbose) VERBOSE="$value" ;;
                *)
                    [ "$VERBOSE" = true ] && echo "Unknown configuration option '$key' in '$CONFIG_FILE'"
                    ;;
            esac
        done < "$CONFIG_FILE"
    else
        echo "Error: Configuration file '$CONFIG_FILE' not found."
        exit 1
    fi
}

function check_root {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: This script must be run with sudo or as root."
        exit 1
    fi
}

# Parse options
TEMP=$(getopt -o harlb:dL:fVc:H: --long help,add,remove,list,backup:,dry-run,log:,force,verbose,config:,hosts: -n "$0" -- "$@")
if ! getopt -o harlb:dL:fVc:H: --long help,add,remove,list,backup:,dry-run,log:,force,verbose,config:,hosts: -n "$0" -- "$@"; then
    echo "Error: Failed to parse options."
    exit 1
fi
eval set -- "$TEMP"

while true; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -a|--add)
            OPERATION="add"
            shift
            ;;
        -r|--remove)
            OPERATION="remove"
            shift
            ;;
        -l|--list)
            OPERATION="list"
            shift
            ;;
        -b|--backup)
            BACKUP_FILE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -L|--log)
            LOG_ENABLED=true
            LOG_FILE="${2:-$LOG_FILE}"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -V|--verbose)
            VERBOSE=true
            shift
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -H|--hosts)
            HOSTS_FILE="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Error: Unknown option '$1'."
            show_help
            ;;
    esac
done

# Load configuration file if specified
if [ -n "$CONFIG_FILE" ]; then
    parse_config_file
fi

# Ensure the script is run as root
check_root

# Handle operations
if [ "$OPERATION" = "list" ]; then
    list_blocked_domains
    exit 0
fi

# Collect domains from arguments
if [ "$#" -lt 1 ] && [ "$OPERATION" != "list" ]; then
    echo "Error: No domain(s) specified."
    show_help
fi

for arg in "$@"; do
    DOMAINS+=("${arg#www.}")
done

if [ -z "$OPERATION" ]; then
    echo "Error: No operation specified (add or remove)."
    show_help
fi

confirm_operation

if [ "$DRY_RUN" = false ]; then
    backup_hosts
fi

modify_hosts "$OPERATION" "${DOMAINS[@]}"

exit 0

