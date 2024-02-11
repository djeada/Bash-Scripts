#!/usr/bin/env bash

# Script Name: for_loop.sh
# Description: Prints numbers from 1 to a given positive number.
# Usage: ./for_loop.sh [number]
# Example: ./for_loop.sh 5

read_positive_number() {
    local n

    while true; do
        echo "Enter a positive number: "
        read -r n

        if [[ $n =~ ^[1-9][0-9]*$ ]]; then
            echo "$n"
            return
        else
            echo "Error: Invalid input. Please enter a positive number."
        fi
    done
}

print_numbers() {
    local n="$1"
    echo "Numbers from 1 to $n:"

    for (( i=1; i<=n; i++ )); do
        echo "$i"
    done
}

main() {
    local n="$1"

    if [[ ! $n =~ ^[1-9][0-9]*$ ]]; then
        n=$(read_positive_number)
    fi

    print_numbers "$n"
}

main "$@"
