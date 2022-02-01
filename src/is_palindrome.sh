#!/usr/bin/env bash

# Script Name: is_palindrome.sh
# Description: Checks if a string is a palindrome.
# Usage: is_palindrome.sh [string]
#       [string] - the string to check
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
    if [[ $# -ne 1 ]]; then
        echo "Usage: is_palindrome.sh [string]"
        echo "       [string] - the string to check"
        exit 1
    fi

    result=$(is_palindrome "$1")
    if [[ "$result" -eq 0 ]]; then
        echo "true"
    else
        echo "false"
    fi
}

main "$@"

