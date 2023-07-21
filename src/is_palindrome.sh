#!/usr/bin/env bash

# Script Name: is_palindrome.sh
# Description: Checks if a string is a palindrome.
# Usage: is_palindrome.sh string
#        string - The string to check
# Example: is_palindrome.sh "racecar"
# Output: true

is_palindrome() {
    local string="$1"
    local length=${#string}
    local half_length=$((length / 2))
    local i=0

    for ((i = 0; i < half_length; i++)); do
        if [[ "${string:i:1}" != "${string:length - i - 1:1}" ]]; then
            return 1
        fi
    done

    return 0
}

main() {
    if (( $# != 1 )); then
        echo "Usage: is_palindrome.sh string"
        echo "       string - The string to check"
        exit 1
    fi

    local string="$1"
    if is_palindrome "$string"; then
        echo "true"
    else
        echo "false"
    fi
}

main "$@"

