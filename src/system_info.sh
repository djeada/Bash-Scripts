#!/usr/bin/env bash

# Script Name: system_info.sh
# Description: This script displays detailed information about the system.
# Usage: ./system_info.sh [options]
# Example: ./system_info.sh --memory --disk

# Enforce strict mode
set -euo pipefail

# Constants
readonly SCRIPT_NAME=$(basename "${0}")

print_usage() {
    echo "Usage: ${SCRIPT_NAME} [OPTIONS]"
    echo "Displays detailed information about the system."
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

print_help() {
    print_usage
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
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            print_help
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
            echo "Error: Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
    shift
done

main() {
    if $show_memory || $show_all; then
        echo -e "Memory Usage: \n$(free -h)\n"
    fi
    if $show_disk || $show_all; then
        echo -e "Disk Usage (Top 10): \n$(df -Ph | sort -k 5 -h -r | head)\n"
    fi
    if $show_cpu || $show_all; then
        echo -e "CPU Information: \n$(lscpu)\n"
    fi
    if $show_network || $show_all; then
        echo -e "Network Interfaces: \n$(ip -br address)\n"
    fi
    if $show_processes || $show_all; then
        echo -e "Running Processes: \n$(ps aux)\n"
    fi
    if $show_os || $show_all; then
        echo -e "Operating System: \n$(lsb_release -a)\n"
    fi
    if $show_kernel || $show_all; then
        echo -e "Kernel Version: \n$(uname -r)\n"
    fi
    if $show_filesystems || $show_all; then
        echo -e "Mounted Filesystems: \n$(mount | grep '^/dev')\n"
    fi
    if $show_load || $show_all; then
        echo -e "System Load: \n$(uptime)\n"
    fi
}

main "$@"
