#!/usr/bin/env bash

# Script Name: for_loop.sh
# Description: Demonstrates the use of a for loop to print numbers from 1 to a given positive number.
# Usage: for_loop.sh
# Example: ./for_loop.sh

read_positive_number() {
    # Prompts the user to enter a positive number and reads the input.
    # Returns the positive number or exits with an error message.

    local n

    while true; do
        echo "Enter a positive number: "
        read -r n

        if [[ $n =~ ^[1-9][0-9]*$ ]]; then
            break
        else
            echo "Error: Invalid input. Please enter a positive number."
        fi
    done

    echo "$n"
}

print_numbers() {
    # Prints numbers from 1 to the given positive number.
    # $1: positive number

    local n="$1"

    echo "Numbers from 1 to $n:"

    for (( i=1; i<=n; i++ )); do
        echo "$i"
    done
}

main() {
    # Main function to execute the script

    local n

    n=$(read_positive_number)
    print_numbers "$n"
}

main "$@"

