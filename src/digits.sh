#!/usr/bin/env bash

# Script Name: digits.sh
# Description: A script to display the digits of a number.
# Usage: digits.sh number
#        number - the number to display the digits of
# Example: ./digits.sh 12345
# Output: 1 2 3 4 5

print_digits() {
    local number=$1
    local digits=()

    while [ "$number" -gt 0 ]; do
        local digit=$((number % 10))
        digits+=("$digit")
        number=$((number / 10))
    done

    for ((i=${#digits[@]}-1; i>=0; i--)); do
        echo -n "${digits[$i]} "
    done
    echo
}

main() {
    if [ $# -ne 1 ]; then
        echo "Usage: digits.sh number"
        echo "       number - the number to display the digits of"
        exit 1
    fi

    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]] ; then
        echo "Invalid input. Please provide a positive integer."
        exit 1
    fi

    print_digits "$1"
}

main "$@"

