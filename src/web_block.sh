#!/usr/bin/env bash

# Script Name: web_block.sh
# Description: Block or unblock websites by modifying the hosts file, with advanced options and features.
#              Blocked domains are mapped to 127.0.0.1 inside a section delimited by
#              "# WEB_BLOCK_START" / "# WEB_BLOCK_END" marker lines; entries outside that
#              section (e.g. "127.0.0.1 localhost") are never listed, changed or removed.
#              A copy of the hosts file is saved to the backup file before every change.
#
# Usage: sudo ./web_block.sh [options] domain1 [domain2 ... domainN]
#        Root is only needed if the hosts file is not writable by the current user.
#
# Options:
#   -h, --help            Display this help message and exit.
#   -a, --add             Block the specified domain(s).
#   -r, --remove          Unblock the specified domain(s).
#   -l, --list            List all currently blocked domains.
#   -b, --backup FILE     Specify a backup file for the hosts file (default: '/etc/hosts.bak').
#   -d, --dry-run         Show what would be done without making changes.
#   -L, --log FILE        Enable logging to the specified file.
#   -f, --force           Force the operation without prompting for confirmation.
#   -V, --verbose         Enable verbose output.
#   -c, --config FILE     Specify a configuration file (key = value lines; keys: hosts_file,
#                         backup_file, log_file, log_enabled, dry_run, force, verbose,
#                         with_www; values for flags are true/false). Command-line
#                         options take precedence over the configuration file.
#   -H, --hosts FILE      Specify a custom hosts file (default: '/etc/hosts').
#   -w, --with-www        Also process the www subdomain of each domain.
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
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly SCRIPT_VERSION="2.0.0"

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

# Block marker comments (matched by prefix, so sections written under another script name still work)
readonly BLOCK_START_PREFIX="# WEB_BLOCK_START"
readonly BLOCK_END_PREFIX="# WEB_BLOCK_END"
readonly BLOCK_START="$BLOCK_START_PREFIX - Managed by web_block.sh"
readonly BLOCK_END="$BLOCK_END_PREFIX - Managed by web_block.sh"

# Show the header comment block; exits with the given status (default 0)
function show_help() {
    sed -n '3,/^[^#]/{/^#/s/^# \{0,1\}//p}' "$0"
    echo -e "\n${BLUE}Version:${NC} $SCRIPT_VERSION"
    exit "${1:-0}"
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
        if [[ ! -d "$log_dir" ]] && ! mkdir -p "$log_dir" 2>/dev/null; then
            print_warning "Could not create log directory: $log_dir"
        elif ! { echo "$timestamp [$SCRIPT_NAME]: $message" >> "$LOG_FILE"; } 2>/dev/null; then
            print_warning "Could not write to log file: $LOG_FILE"
        fi
    fi

    if [[ "$VERBOSE" == true ]]; then
        print_info "$message"
    fi
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
    local deps=("getopt" "grep" "awk" "cp" "cat" "mktemp" "sort" "wc")
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

# Print the domains blocked inside the managed section, one per line
function managed_domains() {
    awk -v start="$BLOCK_START_PREFIX" -v end="$BLOCK_END_PREFIX" '
        index($0, start) == 1 { inside = 1; next }
        index($0, end) == 1   { inside = 0; next }
        inside && $1 == "127.0.0.1" && NF >= 2 { print $2 }
    ' "$HOSTS_FILE" 2>/dev/null
}

function is_domain_blocked() {
    managed_domains | grep -qxF -- "$1"
}

# Rewrite the hosts file with the output of: awk <program> <hosts file>.
# The result is written back through the existing file (cat >), which keeps its
# permissions, ownership and inode (also works for bind-mounted /etc/hosts).
function rewrite_hosts() {
    local tmp
    tmp=$(mktemp) || { print_error "Cannot create temporary file"; exit 1; }
    if ! awk "$@" "$HOSTS_FILE" > "$tmp" || ! cat "$tmp" > "$HOSTS_FILE"; then
        rm -f "$tmp"
        print_error "Failed to update $HOSTS_FILE (backup: $BACKUP_FILE)"
        exit 1
    fi
    rm -f "$tmp"
}

function add_managed_section() {
    if ! grep -q "^$BLOCK_START_PREFIX" "$HOSTS_FILE" 2>/dev/null; then
        {
            echo ""
            echo "$BLOCK_START"
            echo "$BLOCK_END"
        } >> "$HOSTS_FILE"
    fi
}

function add_entry() {
    add_managed_section
    # Insert just before the end marker of the managed section
    # shellcheck disable=SC2016  # $0 is awk's, not the shell's
    rewrite_hosts -v end="$BLOCK_END_PREFIX" -v entry="127.0.0.1 $1" '
        index($0, end) == 1 && !done { print entry; done = 1 }
        { print }
    '
}

function remove_entry() {
    # shellcheck disable=SC2016  # $0, $1, $2 are awk's, not the shell's
    rewrite_hosts -v start="$BLOCK_START_PREFIX" -v end="$BLOCK_END_PREFIX" -v domain="$1" '
        index($0, start) == 1 { inside = 1 }
        index($0, end) == 1   { inside = 0 }
        inside && $1 == "127.0.0.1" && $2 == domain { next }
        { print }
    '
}

function modify_hosts() {
    local action="$1"
    shift
    local input_domains=("$@")
    local processed_count=0
    local skipped_count=0
    local invalid_count=0
    local domain target_domain action_msg
    local -a domains_to_process

    for domain in "${input_domains[@]}"; do
        if ! validate_domain "$domain"; then
            invalid_count=$((invalid_count + 1))
            continue
        fi

        # Get all domains to process (including www if requested)
        mapfile -t domains_to_process < <(get_domains_to_process "$domain")

        for target_domain in "${domains_to_process[@]}"; do
            case "$action" in
                add)
                    if is_domain_blocked "$target_domain"; then
                        action_msg="Domain '$target_domain' is already blocked"
                        skipped_count=$((skipped_count + 1))
                    elif [[ "$DRY_RUN" == false ]]; then
                        add_entry "$target_domain"
                        action_msg="Blocked domain '$target_domain'"
                        processed_count=$((processed_count + 1))
                    else
                        action_msg="[Dry Run] Would block domain '$target_domain'"
                    fi
                    ;;
                remove)
                    if ! is_domain_blocked "$target_domain"; then
                        action_msg="Domain '$target_domain' is not currently blocked"
                        skipped_count=$((skipped_count + 1))
                    elif [[ "$DRY_RUN" == false ]]; then
                        remove_entry "$target_domain"
                        action_msg="Unblocked domain '$target_domain'"
                        processed_count=$((processed_count + 1))
                    else
                        action_msg="[Dry Run] Would unblock domain '$target_domain'"
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
    if [[ $invalid_count -gt 0 ]]; then
        return 1
    fi
}

function list_blocked_domains() {
    print_info "Currently blocked domains:"

    local blocked_domains
    blocked_domains=$(managed_domains | sort -u)

    if [[ -z "$blocked_domains" ]]; then
        echo "  No domains are currently blocked."
    else
        local domain
        while read -r domain; do
            echo "  - $domain"
        done <<< "$blocked_domains"
        echo ""
        echo "Total: $(wc -l <<< "$blocked_domains") blocked domain(s)"
    fi
}

function show_domain_status() {
    local domains=("$@")
    local domain target_domain status=0
    local -a domains_to_check

    print_info "Domain status:"

    for domain in "${domains[@]}"; do
        if ! validate_domain "$domain"; then
            status=1
            continue
        fi

        mapfile -t domains_to_check < <(get_domains_to_process "$domain")

        for target_domain in "${domains_to_check[@]}"; do
            if is_domain_blocked "$target_domain"; then
                echo -e "  - $target_domain: ${RED}BLOCKED${NC}"
            else
                echo -e "  - $target_domain: ${GREEN}NOT BLOCKED${NC}"
            fi
        done
    done
    return "$status"
}

function clear_all_blocked() {
    local blocked_count
    blocked_count=$(managed_domains | wc -l)

    if ! grep -q "^$BLOCK_START_PREFIX" "$HOSTS_FILE" 2>/dev/null; then
        print_info "No blocked domains found"
        return 0
    fi

    print_warning "This will remove all $blocked_count blocked domain(s)"

    if [[ "$DRY_RUN" == false ]]; then
        # Drop the whole managed section (and the blank line added before it)
        # shellcheck disable=SC2016  # $0 is awk's, not the shell's
        rewrite_hosts -v start="$BLOCK_START_PREFIX" -v end="$BLOCK_END_PREFIX" '
            index($0, start) == 1 { inside = 1; blank = 0; next }
            inside { if (index($0, end) == 1) inside = 0; next }
            blank { print ""; blank = 0 }
            $0 == "" { blank = 1; next }
            { print }
            END { if (blank) print "" }
        '
        print_success "Cleared all blocked domains"
        log_action "Cleared all blocked domains ($blocked_count total)"
    else
        print_info "[Dry Run] Would clear all blocked domains"
    fi
}

function confirm_operation() {
    if [[ "$FORCE" == false ]]; then
        local response=""
        read -r -p "Are you sure you want to proceed? (y/N): " response || true
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

function trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

function parse_bool() {
    local key="$1" value="$2"
    case "${value,,}" in
        true|yes|1) echo true ;;
        false|no|0) echo false ;;
        *)
            print_error "Invalid value for '$key' in $CONFIG_FILE: '$value' (use true or false)"
            exit 1
            ;;
    esac
}

function parse_config_file() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file not found: '$CONFIG_FILE'"
        exit 1
    fi

    local key value
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        key=$(trim "$key")
        value=$(trim "$value")

        # Skip comments and empty lines
        [[ -z "$key" || "$key" == \#* ]] && continue

        case "$key" in
            hosts_file) HOSTS_FILE="$value" ;;
            backup_file) BACKUP_FILE="$value" ;;
            log_file) LOG_FILE="$value" ;;
            log_enabled) LOG_ENABLED=$(parse_bool "$key" "$value") ;;
            dry_run) DRY_RUN=$(parse_bool "$key" "$value") ;;
            force) FORCE=$(parse_bool "$key" "$value") ;;
            verbose) VERBOSE=$(parse_bool "$key" "$value") ;;
            with_www) WITH_WWW=$(parse_bool "$key" "$value") ;;
            *) print_warning "Unknown configuration option: '$key'" ;;
        esac
    done < "$CONFIG_FILE"

    log_action "Loaded configuration from: $CONFIG_FILE"
}

function validate_files() {
    # Check if hosts file exists and is writable
    if [[ ! -f "$HOSTS_FILE" ]]; then
        print_error "Hosts file not found: $HOSTS_FILE"
        exit 1
    fi

    if [[ ! -w "$HOSTS_FILE" ]]; then
        print_error "Hosts file is not writable: $HOSTS_FILE (run with sudo or as root)"
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

check_dependencies

# Parse command line options
if ! TEMP=$(getopt -o harlb:dL:fVc:H:wsRC --long help,add,remove,list,backup:,dry-run,log:,force,verbose,config:,hosts:,with-www,status,restore,clear -n "$SCRIPT_NAME" -- "$@"); then
    print_error "Failed to parse command line options"
    exit 1
fi

eval set -- "$TEMP"

# Load the configuration file first, so command-line options override it
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
    case "${args[i]}" in
        -c|--config) CONFIG_FILE="${args[i + 1]}"; i=$((i + 1)) ;;
        -b|--backup|-L|--log|-H|--hosts) i=$((i + 1)) ;;
        --) break ;;
    esac
done
if [[ -n "$CONFIG_FILE" ]]; then
    parse_config_file
fi

set_operation() {
    if [[ -n "$OPERATION" && "$OPERATION" != "$1" ]]; then
        print_error "Only one operation can be given (got --$OPERATION and --$1)"
        exit 1
    fi
    OPERATION="$1"
}

while true; do
    case "$1" in
        -h|--help) show_help ;;
        -a|--add) set_operation add; shift ;;
        -r|--remove) set_operation remove; shift ;;
        -l|--list) set_operation list; shift ;;
        -s|--status) set_operation status; shift ;;
        -R|--restore) set_operation restore; shift ;;
        -C|--clear) set_operation clear; shift ;;
        -b|--backup) BACKUP_FILE="$2"; shift 2 ;;
        -d|--dry-run) DRY_RUN=true; shift ;;
        -L|--log) LOG_ENABLED=true; LOG_FILE="$2"; shift 2 ;;
        -f|--force) FORCE=true; shift ;;
        -V|--verbose) VERBOSE=true; shift ;;
        -w|--with-www) WITH_WWW=true; shift ;;
        -c|--config) shift 2 ;;  # already loaded above
        -H|--hosts) HOSTS_FILE="$2"; shift 2 ;;
        --) shift; break ;;
        *) print_error "Unknown option: '$1'"; show_help 1 ;;
    esac
done

# Main execution starts here
main() {
    # Operations that change the hosts file need write access to it
    # (read-only operations and dry runs don't)
    case "$OPERATION" in
        add|remove|restore|clear)
            if [[ "$DRY_RUN" == false ]]; then
                validate_files
            fi
            ;;
    esac

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
            backup_hosts
            clear_all_blocked
            exit 0
            ;;
        "")
            print_error "No operation specified"
            show_help 1
            ;;
    esac

    # Collect domains from arguments
    if [[ $# -lt 1 ]]; then
        print_error "No domain(s) specified"
        show_help 1
    fi

    # Domains are case-insensitive: store them in lowercase
    local arg
    for arg in "$@"; do
        DOMAINS+=("${arg,,}")
    done

    # Handle operations that require domains
    case "$OPERATION" in
        add|remove)
            confirm_operation
            backup_hosts
            modify_hosts "$OPERATION" "${DOMAINS[@]}"
            ;;
        status)
            show_domain_status "${DOMAINS[@]}"
            ;;
    esac
}

# Run main function
main "$@"

