#!/usr/bin/env bash

# Script Name: check_if_root.sh
# Description: This script verifies if it is being run as root and provides a relevant message if not.
# Usage: ./check_if_root.sh

# Function: Check if the user is root
check_root() {
    # Using id -u to fetch user ID. Root user ID is always 0
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: This script must be run as root."
        echo "You may try using: sudo bash $0"
        return 1
    else
        echo "Script is running with root privileges."
        return 0
    fi
}

# Function: Main function to control the script flow
main() {
    check_root
    exit $?
}

main
