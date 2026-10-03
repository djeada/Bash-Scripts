#!/usr/bin/env bash

# Script Name: system_info.sh
# Description: This script displays detailed information about the system.
#              Without options, all available information is displayed.
# Usage: ./system_info.sh [options]
# Example: ./system_info.sh --memory --disk

# Enforce strict mode
set -euo pipefail

# Constants
SCRIPT_NAME=$(basename "${0}")
readonly SCRIPT_NAME

print_usage() {
    echo "Usage: ${SCRIPT_NAME} [OPTIONS]"
    echo "Displays detailed information about the system."
    echo "Without options, all available information is displayed."
    echo
    echo "Options:"
    echo "  -h, --help      Display this help message and exit."
    echo "  --memory        Display memory usage."
    echo "  --disk          Display disk usage."
    echo "  --cpu           Display CPU information."
    echo "  --network       Display network interfaces."
    echo "  --processes     Display running processes."
    echo "  --os            Display operating system details."
    echo "  --kernel        Display kernel version."
    echo "  --filesystems   Display mounted filesystems."
    echo "  --load          Display system load."
    echo "  --all           Display all available information."
}

# Default options
show_memory=false
show_disk=false
show_cpu=false
show_network=false
show_processes=false
show_os=false
show_kernel=false
show_filesystems=false
show_load=false
show_all=false

# Parse command-line options
if [[ $# -eq 0 ]]; then
    show_all=true
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            print_usage
            exit 0
            ;;
        --memory)
            show_memory=true
            ;;
        --disk)
            show_disk=true
            ;;
        --cpu)
            show_cpu=true
            ;;
        --network)
            show_network=true
            ;;
        --processes)
            show_processes=true
            ;;
        --os)
            show_os=true
            ;;
        --kernel)
            show_kernel=true
            ;;
        --filesystems)
            show_filesystems=true
            ;;
        --load)
            show_load=true
            ;;
        --all)
            show_all=true
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            print_usage >&2
            exit 1
            ;;
    esac
    shift
done

# Print a section title followed by the output of a command.
# Output is printed verbatim (no echo -e escape interpretation).
section() {
    local title="$1"
    shift

    printf '%s:\n' "$title"
    "$@" || printf '(could not retrieve %s)\n' "$title" >&2
    echo
}

disk_usage_top10() {
    # Keep the header line on top and sort the rest by use percentage
    df -Ph | {
        IFS= read -r header
        printf '%s\n' "$header"
        sort -k 5,5 -n -r | head -n 10
    }
}

os_details() {
    if command -v lsb_release >/dev/null 2>&1; then
        lsb_release -a 2>/dev/null
    else
        cat /etc/os-release
    fi
}

dev_filesystems() {
    mount | grep '^/dev' || true
}

main() {
    if $show_memory || $show_all; then
        section "Memory Usage" free -h
    fi
    if $show_disk || $show_all; then
        section "Disk Usage (Top 10)" disk_usage_top10
    fi
    if $show_cpu || $show_all; then
        section "CPU Information" lscpu
    fi
    if $show_network || $show_all; then
        section "Network Interfaces" ip -br address
    fi
    if $show_processes || $show_all; then
        section "Running Processes" ps aux
    fi
    if $show_os || $show_all; then
        section "Operating System" os_details
    fi
    if $show_kernel || $show_all; then
        section "Kernel Version" uname -r
    fi
    if $show_filesystems || $show_all; then
        section "Mounted Filesystems" dev_filesystems
    fi
    if $show_load || $show_all; then
        section "System Load" uptime
    fi
}

main

