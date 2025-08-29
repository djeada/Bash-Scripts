#!/usr/bin/env bash
set -euo pipefail

# Script Name: zombies.sh
# Description: Displays zombie (defunct) processes currently present in the system
#              and provides information about their parent processes.
# Usage: chmod +x zombies.sh && ./zombies.sh [OPTIONS]
# Options:
#   -h, --help      Show this help message
#   -v, --verbose   Show verbose output with detailed process information
#   -c, --count     Show only the count of zombie processes
#   -w, --watch     Continuously monitor for zombie processes (Ctrl+C to stop)
#   -p, --parents   Show information about parent processes of zombies
#   -u, --user      Show zombie processes for current user only
#   -t, --tree      Show process tree for zombie processes
# Examples:
#   ./zombies.sh                    # Show all zombie processes
#   ./zombies.sh --verbose          # Show detailed information
#   ./zombies.sh --count            # Show only count
#   ./zombies.sh --watch            # Monitor continuously
#   ./zombies.sh --parents          # Include parent process info

# Color codes for output formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Global variables for options
VERBOSE=false
COUNT_ONLY=false
WATCH_MODE=false
SHOW_PARENTS=false
USER_ONLY=false
SHOW_TREE=false
SHOW_HELP=false
WATCH_INTERVAL=2

# Function to display help
show_help() {
    cat << EOF
${BOLD}Usage:${NC} $0 [OPTIONS]

This script displays zombie (defunct) processes currently present in the system.
Zombie processes are terminated processes that still have entries in the process 
table because their parent hasn't read their exit status yet.

${BOLD}OPTIONS:${NC}
    -h, --help      Show this help message and exit
    -v, --verbose   Show verbose output with detailed process information
    -c, --count     Show only the count of zombie processes
    -w, --watch     Continuously monitor for zombie processes (Ctrl+C to stop)
    -p, --parents   Show information about parent processes of zombies
    -u, --user      Show zombie processes for current user only
    -t, --tree      Show process tree for zombie processes

${BOLD}EXAMPLES:${NC}
    $0                    # Show all zombie processes
    $0 --verbose          # Show detailed process information
    $0 --count            # Show only the number of zombie processes
    $0 --watch            # Monitor zombie processes continuously
    $0 --parents          # Include parent process information
    $0 --user --verbose   # Show current user's zombies with details

${BOLD}ABOUT ZOMBIE PROCESSES:${NC}
    - Zombie processes consume minimal system resources (just process table entry)
    - They indicate that a parent process hasn't properly waited for child termination
    - Large numbers of zombies may indicate a bug in parent processes
    - Zombies are automatically cleaned up when their parent process exits

${BOLD}TROUBLESHOOTING:${NC}
    - If you see many zombies, check the parent process for bugs
    - Killing the parent process will clean up zombie children
    - Zombies cannot be killed directly with kill signals
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
            -w|--watch)
                WATCH_MODE=true
                shift
                ;;
            -p|--parents)
                SHOW_PARENTS=true
                shift
                ;;
            -u|--user)
                USER_ONLY=true
                shift
                ;;
            -t|--tree)
                SHOW_TREE=true
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

# Function to check if required commands are available
check_dependencies() {
    local missing_deps=()
    local optional_deps=()
    
    # Required commands
    for cmd in ps awk sort grep; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Optional commands for enhanced features
    if [[ "$SHOW_TREE" == true ]] && ! command -v "pstree" >/dev/null 2>&1; then
        optional_deps+=("pstree")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}Error: Missing required commands: ${missing_deps[*]}${NC}" >&2
        exit 1
    fi
    
    if [[ ${#optional_deps[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Warning: Missing optional commands: ${optional_deps[*]}${NC}" >&2
        echo -e "${YELLOW}Some features may not work as expected.${NC}" >&2
    fi
}

# Function to get parent process information
get_parent_info() {
    local ppid=$1
    local parent_info
    
    if [[ "$ppid" == "0" ]]; then
        echo "kernel"
    else
        parent_info=$(ps -p "$ppid" -o pid,user,comm --no-headers 2>/dev/null | head -n1)
        if [[ -n "$parent_info" ]]; then
            echo "$parent_info"
        else
            echo "$ppid <parent not found>"
        fi
    fi
}

# Function to display process tree for a zombie
show_process_tree() {
    local pid=$1
    
    if command -v pstree >/dev/null 2>&1; then
        echo -e "${CYAN}Process tree for PID $pid:${NC}"
        pstree -p "$pid" 2>/dev/null || echo "  Unable to display tree for PID $pid"
        echo
    else
        echo -e "${YELLOW}pstree command not available for tree display${NC}"
    fi
}

# Function to format elapsed time
format_elapsed_time() {
    local elapsed=$1
    local days=$((elapsed / 86400))
    local hours=$(((elapsed % 86400) / 3600))
    local minutes=$(((elapsed % 3600) / 60))
    local seconds=$((elapsed % 60))
    
    if [[ $days -gt 0 ]]; then
        printf "%dd %02dh %02dm %02ds" $days $hours $minutes $seconds
    elif [[ $hours -gt 0 ]]; then
        printf "%02dh %02dm %02ds" $hours $minutes $seconds
    elif [[ $minutes -gt 0 ]]; then
        printf "%02dm %02ds" $minutes $seconds
    else
        printf "%02ds" $seconds
    fi
}

# Function to check for zombie processes
check_zombies() {
    local current_time=$(date +%s)
    local zombie_count=0
    local ps_options="-eo pid,ppid,user,comm,state,etime,lstart"
    
    # Adjust ps options for user-only mode
    if [[ "$USER_ONLY" == true ]]; then
        ps_options+=" -u $(id -un)"
    fi
    
    # Get zombie processes
    local zombies
    if ! zombies=$(ps $ps_options --no-headers 2>/dev/null | awk '$5 ~ /^Z/'); then
        echo -e "${RED}Error: Failed to retrieve process information${NC}" >&2
        return 1
    fi
    
    # Count zombies
    if [[ -n "$zombies" ]]; then
        zombie_count=$(echo "$zombies" | wc -l)
    fi
    
    # Handle count-only mode
    if [[ "$COUNT_ONLY" == true ]]; then
        echo "$zombie_count"
        return 0
    fi
    
    # Display results
    if [[ "$zombie_count" -eq 0 ]]; then
        echo -e "${GREEN}✓ No zombie processes found.${NC}"
        return 0
    fi
    
    # Display header
    echo -e "${RED}⚠ Found $zombie_count zombie process(es):${NC}"
    echo
    
    if [[ "$VERBOSE" == true ]]; then
        printf "${BOLD}%-8s %-8s %-12s %-20s %-8s %-12s %s${NC}\n" \
               "PID" "PPID" "USER" "COMMAND" "STATE" "RUNTIME" "STARTED"
        printf "%-8s %-8s %-12s %-20s %-8s %-12s %s\n" \
               "----" "----" "----" "-------" "-----" "-------" "-------"
    else
        printf "${BOLD}%-8s %-8s %-12s %-20s %s${NC}\n" \
               "PID" "PPID" "USER" "COMMAND" "STATE"
        printf "%-8s %-8s %-12s %-20s %s\n" \
               "----" "----" "----" "-------" "-----"
    fi
    
    # Process each zombie
    while IFS=' ' read -r pid ppid user comm state etime lstart; do
        # Skip empty lines
        if [[ -z "$pid" ]]; then
            continue
        fi
        
        # Truncate command name if too long
        if [[ ${#comm} -gt 20 ]]; then
            comm="${comm:0:17}..."
        fi
        
        if [[ "$VERBOSE" == true ]]; then
            printf "${YELLOW}%-8s${NC} ${PURPLE}%-8s${NC} %-12s %-20s ${RED}%-8s${NC} %-12s %s\n" \
                   "$pid" "$ppid" "$user" "$comm" "$state" "$etime" "$lstart"
        else
            printf "${YELLOW}%-8s${NC} ${PURPLE}%-8s${NC} %-12s %-20s ${RED}%s${NC}\n" \
                   "$pid" "$ppid" "$user" "$comm" "$state"
        fi
        
        # Show parent information if requested
        if [[ "$SHOW_PARENTS" == true ]]; then
            local parent_info
            parent_info=$(get_parent_info "$ppid")
            echo -e "  ${CYAN}Parent:${NC} $parent_info"
        fi
        
        # Show process tree if requested
        if [[ "$SHOW_TREE" == true ]]; then
            show_process_tree "$pid"
        fi
        
    done <<< "$zombies"
    
    # Display summary and recommendations
    echo
    echo -e "${BLUE}Summary:${NC}"
    echo -e "  • Total zombie processes: ${YELLOW}$zombie_count${NC}"
    echo -e "  • Zombies consume minimal resources but indicate parent process issues"
    
    if [[ "$zombie_count" -gt 0 ]]; then
        echo
        echo -e "${BLUE}Recommendations:${NC}"
        echo -e "  • Check parent processes for proper child process handling"
        echo -e "  • Consider restarting problematic parent processes"
        echo -e "  • Zombies will be cleaned up when parent processes exit"
    fi
    
    return 0
}

# Function to clear screen (for watch mode)
clear_screen() {
    if command -v clear >/dev/null 2>&1; then
        clear
    else
        printf '\033[2J\033[H'
    fi
}

# Function to run in watch mode
watch_zombies() {
    echo -e "${BLUE}Monitoring zombie processes... (Press Ctrl+C to stop)${NC}"
    echo -e "${BLUE}Update interval: ${WATCH_INTERVAL} seconds${NC}"
    echo
    
    while true; do
        clear_screen
        echo -e "${BOLD}Zombie Process Monitor - $(date)${NC}"
        echo "=================================================================================="
        
        check_zombies
        
        echo
        echo -e "${CYAN}Next update in $WATCH_INTERVAL seconds... (Ctrl+C to stop)${NC}"
        sleep "$WATCH_INTERVAL"
    done
}

# Function to handle cleanup on exit
cleanup() {
    if [[ "$WATCH_MODE" == true ]]; then
        echo
        echo -e "${GREEN}Zombie monitoring stopped.${NC}"
    fi
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
    
    # Set trap for cleanup
    trap cleanup EXIT INT TERM
    
    # Execute appropriate mode
    if [[ "$WATCH_MODE" == true ]]; then
        watch_zombies
    else
        check_zombies
    fi
}

# Run the main function with all arguments
main "$@"
