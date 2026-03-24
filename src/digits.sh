#!/usr/bin/env bash

# Script Name: digits.sh
# Description: A script to display the digits of a number.
#              The script treats the input as a string, so it correctly handles
#              cases like a leading zero or an input of "0".
# Usage: ./digits.sh number
# Example: ./digits.sh 12345

print_digits() {
    local number="$1"
    local len=${#number}

    # Loop over each character in the string
    for (( i = 0; i < len; i++ )); do
        printf "%s " "${number:i:1}"
    done
    echo
}

main() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: $0 number"
        echo "  number - the number (digits only) to display the digits of"
        exit 1
    fi

    # Validate input: ensure that it contains only digits.
    if ! [[ "$1" =~ ^[0-9]+$ ]]; then
        echo "Invalid input. Please provide a positive integer (digits only)."
        exit 1
    fi

    print_digits "$1"
}

main "$@"

