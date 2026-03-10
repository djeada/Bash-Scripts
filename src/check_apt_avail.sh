#!/usr/bin/env bash

# Script Name: check_apt_avail.sh
# Description: Checks if the apt command is available on the system.
# Usage: check_apt_avail.sh
# Example: ./check_apt_avail.sh

check_apt_availability() {
    if ! command -v apt >/dev/null 2>&1; then
        echo "The apt command is not accessible on this system."
        exit 1
    fi
}

print_usage() {
    echo "Usage: check_apt_avail.sh"
}

main() {
    if [[ $# -ne 0 ]]; then
        print_usage
        exit 1
    fi

    check_apt_availability
}

main "$@"

