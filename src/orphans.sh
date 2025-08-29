#!/usr/bin/env bash
set -euo pipefail

# Script Name: orphans.sh
# Description: This script displays processes that might be orphans,
#              i.e. processes whose parent process is not running.
# Usage: chmod +x orphans.sh && ./orphans.sh [OPTIONS]
# Options:
#   -h, --help     Show this help message
#   -v, --verbose  Show verbose output with process details
#   -c, --count    Show only the count of orphaned processes
#   -u, --user     Show processes for current user only
# Examples:
#   ./orphans.sh                    # Show all potential orphans
#   ./orphans.sh --verbose          # Show detailed information
#   ./orphans.sh --count            # Show only count
#   ./orphans.sh --user             # Show only current user's processes

# Color codes for output formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Global variables for options
VERBOSE=false
COUNT_ONLY=false
USER_ONLY=false
SHOW_HELP=false

# Function to display help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

This script displays processes that might be orphans (processes whose parent is not running).

OPTIONS:
    -h, --help      Show this help message and exit
    -v, --verbose   Show verbose output with process details (PID, PPID, CMD)
    -c, --count     Show only the count of orphaned processes
    -u, --user      Show processes for current user only

EXAMPLES:
    $0                    # Show all potential orphans
    $0 --verbose          # Show detailed process information
    $0 --count            # Show only the number of orphaned processes
    $0 --user             # Show only current user's orphaned processes

NOTE:
    - Processes with PPID 0 or 1 are typically not considered orphans
    - Some processes may appear as orphans due to timing between process death and cleanup
    - Use with caution on production systems
EOF
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                SHOW_HELP=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -c|--count)
                COUNT_ONLY=true
                shift
                ;;
            -u|--user)
                USER_ONLY=true
                shift
                ;;
            *)
                echo -e "${RED}Error: Unknown option '$1'${NC}" >&2
                echo "Use --help for usage information." >&2
                exit 1
                ;;
        esac
    done
}

# Create temporary files for process data
create_temp_files() {
    if ! TMP_FILE=$(mktemp /tmp/orphans_processes.XXXXXX 2>/dev/null); then
        echo -e "${RED}Error: Failed to create temporary file${NC}" >&2
        exit 1
    fi
    
    if ! PIDS_TMP_FILE=$(mktemp /tmp/orphans_pids.XXXXXX 2>/dev/null); then
        rm -f "$TMP_FILE"
        echo -e "${RED}Error: Failed to create temporary PID file${NC}" >&2
        exit 1
    fi
}

# Cleanup function to remove temporary files
cleanup() {
    local exit_code=$?
    [[ -n "${TMP_FILE:-}" ]] && rm -f "$TMP_FILE"
    [[ -n "${PIDS_TMP_FILE:-}" ]] && rm -f "$PIDS_TMP_FILE"
    exit $exit_code
}

# Error handling function
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    cleanup
    exit 1
}

# Function to check if required commands are available
check_dependencies() {
    local missing_deps=()
    
    for cmd in ps awk sort grep mktemp; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error_exit "Missing required commands: ${missing_deps[*]}"
    fi
}

# Function to get process information based on user preference
get_process_info() {
    local ps_options="-eo ppid,pid,user,comm"
    
    if [[ "$USER_ONLY" == true ]]; then
        ps_options+=" -u $(id -un)"
    fi
    
    # Get process information and handle potential ps command failures
    if ! ps $ps_options --no-headers 2>/dev/null > "$TMP_FILE"; then
        error_exit "Failed to retrieve process information. You may need elevated privileges."
    fi
    
    # Verify that we got some data
    if [[ ! -s "$TMP_FILE" ]]; then
        error_exit "No process information retrieved"
    fi
}

# Function to create PID lookup table
create_pid_lookup() {
    if ! awk '{print $2}' "$TMP_FILE" | sort -u > "$PIDS_TMP_FILE"; then
        error_exit "Failed to create PID lookup table"
    fi
}

# Function to check for orphan processes
check_orphans() {
    local orphan_count=0
    local line_number=0
    
    if [[ "$VERBOSE" == true && "$COUNT_ONLY" == false ]]; then
        echo -e "${BLUE}Checking for orphaned processes...${NC}"
        printf "%-8s %-8s %-12s %s\n" "PID" "PPID" "USER" "COMMAND"
        printf "%-8s %-8s %-12s %s\n" "----" "----" "----" "-------"
    fi
    
    while IFS=' ' read -r ppid pid user comm; do
        ((line_number++))
        
        # Skip empty lines or malformed entries
        if [[ -z "$ppid" || -z "$pid" ]]; then
            continue
        fi
        
        # Skip processes with PPID 0 (kernel processes) or 1 (init processes)
        # These are typically not considered orphans
        if [[ "$ppid" -eq 0 || "$ppid" -eq 1 ]]; then
            continue
        fi
        
        # Check if the parent PID exists in our running processes
        if ! grep -qw "^$ppid$" "$PIDS_TMP_FILE"; then
            ((orphan_count++))
            
            if [[ "$COUNT_ONLY" == false ]]; then
                if [[ "$VERBOSE" == true ]]; then
                    printf "${YELLOW}%-8s${NC} ${RED}%-8s${NC} %-12s %s\n" "$pid" "$ppid" "$user" "$comm"
                else
                    echo -e "${YELLOW}Process $pid${NC} might be an orphan ${RED}(parent PID: $ppid not found)${NC}"
                fi
            fi
        fi
        
    done < "$TMP_FILE"
    
    # Display results summary
    if [[ "$COUNT_ONLY" == true ]]; then
        echo "$orphan_count"
    else
        echo
        if [[ "$orphan_count" -eq 0 ]]; then
            echo -e "${GREEN}No orphaned processes found.${NC}"
        else
            echo -e "${BLUE}Total potential orphaned processes found: ${YELLOW}$orphan_count${NC}"
            echo -e "${BLUE}Note: Some processes may appear orphaned due to timing between parent death and cleanup.${NC}"
        fi
    fi
    
    return 0
}

# Main function
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Show help if requested
    if [[ "$SHOW_HELP" == true ]]; then
        show_help
        exit 0
    fi
    
    # Check for required dependencies
    check_dependencies
    
    # Create temporary files
    create_temp_files
    
    # Set trap to cleanup on exit
    trap cleanup EXIT INT TERM
    
    # Get process information
    get_process_info
    
    # Create PID lookup table
    create_pid_lookup
    
    # Check for orphaned processes
    check_orphans
}

# Run the main function with all arguments
main "$@"
