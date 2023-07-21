#!/usr/bin/env bash

# Script Name: disk_usage
# Description: Computes and displays total disk usage for the system.
# Usage: ./disk_usage.sh [disk_pattern]
# Example: ./disk_usage.sh sda

# Function to print script usage
print_usage() {
    echo "Usage: $0 [disk_pattern]"
    echo "Computes and displays total disk usage for the system. If a disk pattern is specified, only matches to that pattern are displayed."
}

# Check the number of arguments
if [[ $# -gt 1 ]]; then
    echo "Error: Incorrect number of arguments."
    print_usage
    exit 1
fi

# Parse arguments
disk_pattern="${1:-sda}"

# Main function
main() {
    # Get file system names and percentage of use
    result=$(df -h | awk -v pattern="$disk_pattern" '$1 ~ pattern { print $1 " " $5 }' | cut -d'%' -f1)
    echo -e "Disk usage for pattern \"$disk_pattern\":\n$result"
}

main

