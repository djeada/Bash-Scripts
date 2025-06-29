#!/usr/bin/env bash
set -euo pipefail

# Script Name: zombies.sh
# Description: Displays zombie (defunct) processes currently present in the system.
# Usage: zombies.sh [-h | --help]
# Example: ./zombies.sh

# Function to display the help message
show_help() {
    cat <<EOF
Usage: $0 [-h | --help]

Displays zombie (defunct) processes currently present in the system.

Options:
  -h, --help    Show this help message and exit
EOF
}

# Function to check for zombie processes
check_zombies() {
    # Retrieve process list (without header) and filter those with a state starting with 'Z'
    local zombies
    zombies=$(ps -eo pid,ppid,state,cmd --no-headers | awk '$3 ~ /^Z/')

    if [[ -z "$zombies" ]]; then
        echo "No zombie processes found."
    else
        echo "Zombie processes:"
        printf "%-10s %-10s %-6s %s\n" "PID" "PPID" "STATE" "COMMAND"
        # Format and print each zombie process
        echo "$zombies" | awk '{printf "%-10s %-10s %-6s %s\n", $1, $2, $3, substr($0, index($0,$4))}'
    fi
}

# Parse command-line options
if [[ $# -gt 0 ]]; then
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Invalid option: $1"
            show_help
            exit 1
            ;;
    esac
fi

# Execute the zombie check
check_zombies

