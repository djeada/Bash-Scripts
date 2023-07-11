#!/usr/bin/env bash

# Script Name: system_info
# Description: This script displays detailed information about the system.
# Usage: ./system_info.sh

# Enforce strict mode
set -euo pipefail

# Constants
readonly SCRIPT_NAME=$(basename "${0}")

# Function to print script usage
print_usage() {
    echo "Usage: ${SCRIPT_NAME}"
    echo "Displays detailed information about the system."
}

# Function to print help message
print_help() {
    cat << EOF
${SCRIPT_NAME} - System Information Tool

Usage: ${SCRIPT_NAME} [OPTIONS]

Options:
  -h, --help  Display this help message and exit.

EOF
}

# Parse command-line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
    shift
done

# Main function
main() {
    echo -e "Memory Usage: \n$(free -h)\n"
    echo -e "Disk Usage (Top 10): \n$(df -Ph | sort -k 5 -h -r | head)\n"
    echo -e "Uptime: \n$(uptime)\n"
    echo -e "CPU Information: \n$(lscpu)\n"
    echo -e "Network Interfaces: \n$(ip -br address)\n"
    echo -e "Running Processes: \n$(ps aux)"
}

main "$@"
