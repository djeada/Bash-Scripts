#!/usr/bin/env bash

# Script Name: orphans.sh
# Description: This script displays processes that might be orphans,
#              i.e. processes whose parent process is not running.
# Usage: ./orphans.sh [OPTIONS]
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

set -euo pipefail

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

# Error handling function
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Function to check if required commands are available
check_dependencies() {
    if ! command -v ps >/dev/null 2>&1; then
        error_exit "Missing required command: ps"
    fi
}

# Running PIDs (keys) and the candidate processes to check ("ppid pid user comm" lines)
declare -A RUNNING_PIDS=()
PROCESS_LINES=()

# Function to get process information based on user preference
get_process_info() {
    local all_processes line pid

    # Always look up parents among ALL processes; --user only limits which
    # children are reported (a user's process may have a root-owned parent).
    if ! all_processes=$(ps -eo "ppid,pid,user,comm" --no-headers 2>/dev/null); then
        error_exit "Failed to retrieve process information."
    fi
    if [[ -z "$all_processes" ]]; then
        error_exit "No process information retrieved"
    fi

    local current_user
    current_user=$(id -un)
    while read -r _ pid _; do
        RUNNING_PIDS[$pid]=1
    done <<< "$all_processes"

    while IFS= read -r line; do
        read -r _ _ user _ <<< "$line"
        if [[ "$USER_ONLY" == false || "$user" == "$current_user" ]]; then
            PROCESS_LINES+=("$line")
        fi
    done <<< "$all_processes"
}

# Function to check for orphan processes
check_orphans() {
    local orphan_count=0

    if [[ "$VERBOSE" == true && "$COUNT_ONLY" == false ]]; then
        echo -e "${BLUE}Checking for orphaned processes...${NC}"
        printf "%-8s %-8s %-12s %s\n" "PID" "PPID" "USER" "COMMAND"
        printf "%-8s %-8s %-12s %s\n" "----" "----" "----" "-------"
    fi

    while IFS=' ' read -r ppid pid user comm; do
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
        if [[ -z "${RUNNING_PIDS[$ppid]:-}" ]]; then
            orphan_count=$((orphan_count + 1))

            if [[ "$COUNT_ONLY" == false ]]; then
                if [[ "$VERBOSE" == true ]]; then
                    printf "${YELLOW}%-8s${NC} ${RED}%-8s${NC} %-12s %s\n" "$pid" "$ppid" "$user" "$comm"
                else
                    echo -e "${YELLOW}Process $pid${NC} might be an orphan ${RED}(parent PID: $ppid not found)${NC}"
                fi
            fi
        fi

    done < <(printf '%s\n' "${PROCESS_LINES[@]}")

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

    # Get process information
    get_process_info

    # Check for orphaned processes
    check_orphans
}

# Run the main function with all arguments
main "$@"

