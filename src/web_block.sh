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
#   -w, --with-www        Also block www subdomain when adding domains.
#   -s, --status          Show status of specified domain(s).
#   -R, --restore         Restore hosts file from backup.
#   -C, --clear           Remove all blocked domains.
#
# Examples:
#   sudo ./web_block.sh --add example.com
#   sudo ./web_block.sh --remove example.com --verbose
#   sudo ./web_block.sh --list
#   sudo ./web_block.sh --add example.com example.org --force --with-www
#   sudo ./web_block.sh --config myconfig.conf --add example.com
#   sudo ./web_block.sh --status example.com
#   sudo ./web_block.sh --restore
#   sudo ./web_block.sh --clear --force

set -euo pipefail

# Script metadata
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default configurations
HOSTS_FILE="/etc/hosts"
BACKUP_FILE="/etc/hosts.bak"
LOG_FILE="/var/log/web_block.log"
LOG_ENABLED=false
DRY_RUN=false
FORCE=false
VERBOSE=false
WITH_WWW=false
OPERATION=""
DOMAINS=()
CONFIG_FILE=""

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Block marker comments
readonly BLOCK_START="# WEB_BLOCK_START - Managed by $SCRIPT_NAME"
readonly BLOCK_END="# WEB_BLOCK_END - Managed by $SCRIPT_NAME"

function show_help() {
    grep '^#' "$0" | cut -c 4-
    echo -e "\n${BLUE}Version:${NC} $SCRIPT_VERSION"
    exit 0
}

function print_error() {
    echo -e "${RED}Error:${NC} $1" >&2
}

function print_success() {
    echo -e "${GREEN}Success:${NC} $1"
}

function print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

function print_info() {
    echo -e "${BLUE}Info:${NC} $1"
}

function log_action() {
    local message="$1"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %T")
    
    if [[ "$LOG_ENABLED" == true ]]; then
        # Ensure log directory exists
        local log_dir
        log_dir=$(dirname "$LOG_FILE")
        if [[ ! -d "$log_dir" ]]; then
            mkdir -p "$log_dir" 2>/dev/null || {
                print_warning "Could not create log directory: $log_dir"
                return 1
            }
        fi
        
        echo "$timestamp [$SCRIPT_NAME]: $message" >> "$LOG_FILE" || {
            print_warning "Could not write to log file: $LOG_FILE"
            return 1
        }
    fi
    
    [[ "$VERBOSE" == true ]] && print_info "$message"
}

function validate_domain() {
    local domain="$1"
    
    # More comprehensive domain validation
    if [[ -z "$domain" ]]; then
        print_error "Empty domain name provided"
        return 1
    fi
    
    # Check for invalid characters and basic structure
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        print_error "Invalid domain name format: '$domain'"
        return 1
    fi
    
    # Check length constraints
    if [[ ${#domain} -gt 253 ]]; then
        print_error "Domain name too long: '$domain' (max 253 characters)"
        return 1
    fi
    
    return 0
}

function check_dependencies() {
    local deps=("sed" "grep" "awk" "cp" "cat")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

function backup_hosts() {
    if [[ ! -f "$HOSTS_FILE" ]]; then
        print_error "Hosts file not found: $HOSTS_FILE"
        exit 1
    fi
    
    if [[ "$DRY_RUN" == false ]]; then
        if cp "$HOSTS_FILE" "$BACKUP_FILE"; then
            log_action "Backup created: $BACKUP_FILE"
        else
            print_error "Failed to create backup"
            exit 1
        fi
    else
        log_action "[Dry Run] Would create backup: $BACKUP_FILE"
    fi
}

function restore_hosts() {
    if [[ ! -f "$BACKUP_FILE" ]]; then
        print_error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi
    
    if [[ "$DRY_RUN" == false ]]; then
        if cp "$BACKUP_FILE" "$HOSTS_FILE"; then
            print_success "Hosts file restored from backup"
            log_action "Hosts file restored from backup: $BACKUP_FILE"
        else
            print_error "Failed to restore hosts file"
            exit 1
        fi
    else
        print_info "[Dry Run] Would restore hosts file from: $BACKUP_FILE"
    fi
}

function get_domains_to_process() {
    local domain="$1"
    local domains_list=("$domain")
    
    # Add www subdomain if requested
    if [[ "$WITH_WWW" == true && ! "$domain" =~ ^www\. ]]; then
        domains_list+=("www.$domain")
    fi
    
    printf '%s\n' "${domains_list[@]}"
}

function is_domain_blocked() {
    local domain="$1"
    grep -qF "127.0.0.1 $domain" "$HOSTS_FILE" 2>/dev/null
}

function add_managed_section() {
    if [[ "$DRY_RUN" == false ]]; then
        if ! grep -qF "$BLOCK_START" "$HOSTS_FILE" 2>/dev/null; then
            {
                echo ""
                echo "$BLOCK_START"
                echo "$BLOCK_END"
            } >> "$HOSTS_FILE"
        fi
    fi
}

function modify_hosts() {
    local action="$1"
    shift
    local input_domains=("$@")
    local processed_count=0
    local skipped_count=0
    
    for domain in "${input_domains[@]}"; do
        validate_domain "$domain" || continue
        
        # Get all domains to process (including www if requested)
        mapfile -t domains_to_process < <(get_domains_to_process "$domain")
        
        for target_domain in "${domains_to_process[@]}"; do
            local entry="127.0.0.1 $target_domain"
            local action_msg=""
            
            case "$action" in
                add)
                    if is_domain_blocked "$target_domain"; then
                        action_msg="Domain '$target_domain' is already blocked"
                        ((skipped_count++))
                    else
                        if [[ "$DRY_RUN" == false ]]; then
                            add_managed_section
                            # Insert before the end marker
                            sed -i.tmp "/^${BLOCK_END//\//\\/}$/i\\
$entry" "$HOSTS_FILE" && rm -f "$HOSTS_FILE.tmp"
                            action_msg="Blocked domain '$target_domain'"
                            ((processed_count++))
                        else
                            action_msg="[Dry Run] Would block domain '$target_domain'"
                        fi
                    fi
                    ;;
                remove)
                    if is_domain_blocked "$target_domain"; then
                        if [[ "$DRY_RUN" == false ]]; then
                            sed -i.tmp "/^127\.0\.0\.1[[:space:]]\+$(printf '%s\n' "$target_domain" | sed 's/[[\.*^$()+?{|]/\\&/g')$/d" "$HOSTS_FILE" && rm -f "$HOSTS_FILE.tmp"
                            action_msg="Unblocked domain '$target_domain'"
                            ((processed_count++))
                        else
                            action_msg="[Dry Run] Would unblock domain '$target_domain'"
                        fi
                    else
                        action_msg="Domain '$target_domain' is not currently blocked"
                        ((skipped_count++))
                    fi
                    ;;
                *)
                    print_error "Invalid operation: $action"
                    exit 1
                    ;;
            esac
            
            echo "$action_msg"
            log_action "$action_msg"
        done
    done
    
    # Summary
    if [[ $processed_count -gt 0 ]]; then
        print_success "Processed $processed_count domain(s)"
    fi
    if [[ $skipped_count -gt 0 ]]; then
        print_info "Skipped $skipped_count domain(s)"
    fi
}

function list_blocked_domains() {
    print_info "Currently blocked domains:"
    
    local blocked_domains
    blocked_domains=$(grep "^127\.0\.0\.1[[:space:]]" "$HOSTS_FILE" 2>/dev/null | awk '{print $2}' | sort -u)
    
    if [[ -z "$blocked_domains" ]]; then
        echo "  No domains are currently blocked."
    else
        echo "$blocked_domains" | while read -r domain; do
            echo "  - $domain"
        done
        echo ""
        echo "Total: $(echo "$blocked_domains" | wc -l) blocked domain(s)"
    fi
}

function show_domain_status() {
    local domains=("$@")
    
    print_info "Domain status:"
    
    for domain in "${domains[@]}"; do
        validate_domain "$domain" || continue
        
        mapfile -t domains_to_check < <(get_domains_to_process "$domain")
        
        for target_domain in "${domains_to_check[@]}"; do
            if is_domain_blocked "$target_domain"; then
                echo -e "  - $target_domain: ${RED}BLOCKED${NC}"
            else
                echo -e "  - $target_domain: ${GREEN}NOT BLOCKED${NC}"
            fi
        done
    done
}

function clear_all_blocked() {
    local blocked_count
    blocked_count=$(grep -c "^127\.0\.0\.1[[:space:]]" "$HOSTS_FILE" 2>/dev/null || echo "0")
    
    if [[ $blocked_count -eq 0 ]]; then
        print_info "No blocked domains found"
        return 0
    fi
    
    print_warning "This will remove all $blocked_count blocked domain(s)"
    
    if [[ "$DRY_RUN" == false ]]; then
        # Remove all 127.0.0.1 entries and managed section
        sed -i.tmp '/^127\.0\.0\.1[[:space:]]/d; /^# WEB_BLOCK_START/,/^# WEB_BLOCK_END/d' "$HOSTS_FILE" && rm -f "$HOSTS_FILE.tmp"
        print_success "Cleared all blocked domains"
        log_action "Cleared all blocked domains ($blocked_count total)"
    else
        print_info "[Dry Run] Would clear all blocked domains"
    fi
}

function confirm_operation() {
    if [[ "$FORCE" == false ]]; then
        local response
        read -r -p "Are you sure you want to proceed? (y/N): " response
        case "$response" in
            [yY]|[yY][eE][sS])
                return 0
                ;;
            *)
                print_info "Operation cancelled"
                exit 0
                ;;
        esac
    fi
}

function parse_config_file() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file not found: '$CONFIG_FILE'"
        exit 1
    fi
    
    log_action "Loading configuration from: $CONFIG_FILE"
    
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        
        # Trim whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        
        case "$key" in
            hosts_file) HOSTS_FILE="$value" ;;
            backup_file) BACKUP_FILE="$value" ;;
            log_file) LOG_FILE="$value" ;;
            log_enabled) LOG_ENABLED="$value" ;;
            dry_run) DRY_RUN="$value" ;;
            force) FORCE="$value" ;;
            verbose) VERBOSE="$value" ;;
            with_www) WITH_WWW="$value" ;;
            *)
                [[ "$VERBOSE" == true ]] && print_warning "Unknown configuration option: '$key'"
                ;;
        esac
    done < "$CONFIG_FILE"
}

function check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run with sudo or as root"
        exit 1
    fi
}

function validate_files() {
    # Check if hosts file exists and is writable
    if [[ ! -f "$HOSTS_FILE" ]]; then
        print_error "Hosts file not found: $HOSTS_FILE"
        exit 1
    fi
    
    if [[ ! -w "$HOSTS_FILE" ]]; then
        print_error "Hosts file is not writable: $HOSTS_FILE"
        exit 1
    fi
    
    # Check backup directory
    local backup_dir
    backup_dir=$(dirname "$BACKUP_FILE")
    if [[ ! -d "$backup_dir" ]]; then
        if ! mkdir -p "$backup_dir" 2>/dev/null; then
            print_error "Cannot create backup directory: $backup_dir"
            exit 1
        fi
    fi
}

# Parse command line options
if ! TEMP=$(getopt -o harlb:dL:fVc:H:wsRC --long help,add,remove,list,backup:,dry-run,log:,force,verbose,config:,hosts:,with-www,status,restore,clear -n "$SCRIPT_NAME" -- "$@"); then
    print_error "Failed to parse command line options"
    exit 1
fi

eval set -- "$TEMP"

while true; do
    case "$1" in
        -h|--help) show_help ;;
        -a|--add) OPERATION="add"; shift ;;
        -r|--remove) OPERATION="remove"; shift ;;
        -l|--list) OPERATION="list"; shift ;;
        -s|--status) OPERATION="status"; shift ;;
        -R|--restore) OPERATION="restore"; shift ;;
        -C|--clear) OPERATION="clear"; shift ;;
        -b|--backup) BACKUP_FILE="$2"; shift 2 ;;
        -d|--dry-run) DRY_RUN=true; shift ;;
        -L|--log) LOG_ENABLED=true; LOG_FILE="${2:-$LOG_FILE}"; shift 2 ;;
        -f|--force) FORCE=true; shift ;;
        -V|--verbose) VERBOSE=true; shift ;;
        -w|--with-www) WITH_WWW=true; shift ;;
        -c|--config) CONFIG_FILE="$2"; shift 2 ;;
        -H|--hosts) HOSTS_FILE="$2"; shift 2 ;;
        --) shift; break ;;
        *) print_error "Unknown option: '$1'"; show_help ;;
    esac
done

# Main execution starts here
main() {
    # Check dependencies first
    check_dependencies
    
    # Load configuration file if specified
    if [[ -n "$CONFIG_FILE" ]]; then
        parse_config_file
    fi
    
    # Ensure the script is run as root (except for help and some read-only operations)
    if [[ "$OPERATION" != "list" && "$OPERATION" != "status" && "$OPERATION" != "help" ]]; then
        check_root
        validate_files
    fi
    
    # Handle operations that don't require domains
    case "$OPERATION" in
        list)
            list_blocked_domains
            exit 0
            ;;
        restore)
            confirm_operation
            restore_hosts
            exit 0
            ;;
        clear)
            confirm_operation
            if [[ "$DRY_RUN" == false ]]; then
                backup_hosts
            fi
            clear_all_blocked
            exit 0
            ;;
        "")
            print_error "No operation specified"
            show_help
            ;;
    esac
    
    # Collect domains from arguments
    if [[ $# -lt 1 ]]; then
        print_error "No domain(s) specified"
        show_help
    fi
    
    # Remove www prefix and add to domains array
    for arg in "$@"; do
        DOMAINS+=("${arg#www.}")
    done
    
    # Handle operations that require domains
    case "$OPERATION" in
        add|remove)
            confirm_operation
            if [[ "$DRY_RUN" == false ]]; then
                backup_hosts
            fi
            modify_hosts "$OPERATION" "${DOMAINS[@]}"
            ;;
        status)
            show_domain_status "${DOMAINS[@]}"
            ;;
        *)
            print_error "Invalid operation: $OPERATION"
            show_help
            ;;
    esac
}

# Run main function
main "$@"
