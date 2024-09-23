#!/usr/bin/env bash

# Script Name: zombies.sh
# Description: Displays zombie (defunct) processes currently present in the system.
# Usage: bash zombies.sh [-h | --help]
# Example: ./zombies.sh

# Function to display the help message
show_help() {
    echo "Usage: $0 [-h | --help]"
    echo
    echo "Displays zombie (defunct) processes currently present in the system."
    echo
    echo "Options:"
    echo "  -h, --help    Show this help message and exit"
}

# Function to check for zombie processes
check_zombies() {
    local zombies

    # Fetch zombie processes
    zombies=$(ps -eo pid,ppid,state,cmd --no-headers | awk '$3 ~ /Z/')

    if [[ -z "$zombies" ]]; then
        echo "No zombie processes found."
    else
        echo "Zombie processes:"
        printf "%-10s %-10s %-6s %s\n" "PID" "PPID" "STATE" "COMMAND"
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

# Execute the main function
check_zombies
