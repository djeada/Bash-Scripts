#!/usr/bin/env bash

# Script Name: cpu_usage.sh
# Description: Displays the current CPU usage.
# Usage: ./cpu_usage.sh [ -p PROCESS_NAME | -u USERNAME ]
# Example: ./cpu_usage.sh -p firefox -u root

# Function to check for required commands
check_required_commands() {
    for cmd in top ps awk pgrep; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: Required command '$cmd' not found" >&2
            exit 1
        fi
    done
}

# Function to get the overall CPU usage
get_total_cpu_usage() {
    top -bn1 | awk '/Cpu\(s\):/ {print 100 - $8"%"}'
}

# Function to get the top 10 CPU consuming processes
get_top_processes() {
    echo "Top 10 CPU consuming processes:"
    ps -eo user,pid,%cpu,comm --sort=-%cpu | head -n 11
}

# Function to get the top 10 CPU consuming processes for a specific user
get_top_processes_for_user() {
    local user="$1"
    echo "Top 10 CPU consuming processes for user '$user':"
    ps -eo user,pid,%cpu,comm --sort=-%cpu | awk -v user="$user" '$1==user' | head -n 11
}

# Function to get CPU usage for a specific process name
get_process_cpu_usage() {
    local process="$1"
    echo "CPU usage for processes matching '$process':"
    pgrep -fl "$process" | while read -r pid _; do
        ps -p "$pid" -o user,pid,%cpu,comm --no-headers
    done
}

main() {
    check_required_commands

    local process
    local user

    echo "Total CPU usage: $(get_total_cpu_usage)"

    while getopts ":p:u:" option; do
        case "${option}" in
            p) process=${OPTARG} ;;
            u) user=${OPTARG} ;;
            *) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
        esac
    done
    shift $((OPTIND -1))

    if [[ -n "$process" ]]; then
        get_process_cpu_usage "$process"
        exit 0
    fi

    if [[ -n "$user" ]]; then
        get_top_processes_for_user "$user"
    else
        get_top_processes
    fi
}

main "$@"
