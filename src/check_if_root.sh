#!/usr/bin/env bash

# Script Name: check_if_root.sh
# Description: Check if the user is root or not and exit if not.
# Usage: check_if_root.sh
# Example: ./check_if_root.sh

main() {

    if [ $(id -u) -ne 0 ]; then
        echo "This script must be executed with root privileges. Try: sudo bash $0"
        exit 1
    fi

}

main "$@"
