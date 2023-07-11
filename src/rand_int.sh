#!/usr/bin/env bash

# Script Name: rand_int.sh
# Description: Generates a random integer within a specific range.
# Usage: rand_int.sh lower_bound upper_bound
#        lower_bound - the smallest number that could be generated.
#        upper_bound - the largest number that could be generated.
# Example: ./rand_int.sh 1 10

generate_random_integer() {
    # Generates a random integer within the specified range
    # $1: lower bound
    # $2: upper bound
    local min="$1"
    local max="$2"

    echo $((RANDOM % (max + 1 - min) + min))
}

main() {
    # Main function to orchestrate the script

    if [ $# -ne 2 ]; then
        echo "Must provide exactly two numbers!"
        exit 1
    fi

    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]]; then
        echo "$1 is not a positive integer!"
        exit 1
    fi

    if ! [[ $2 =~ $re ]]; then
        echo "$2 is not a positive integer!"
        exit 1
    fi

    local min="$1"
    local max="$2"

    generate_random_integer "$min" "$max"
}

main "$@"
