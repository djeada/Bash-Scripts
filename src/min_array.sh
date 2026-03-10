#!/usr/bin/env bash

# Script Name: min_array.sh
# Description: Find the minimum value in an array.
# Usage: min_array.sh val1 val2 ...
#        val1 val2 ... - a list of values separated by spaces
# Example: min_array.sh 4 5 6 1 2 3
# Output: 1

find_minimum() {
    # Finds the minimum value in an array
    # $@: a list of values

    local min=${1}
    shift
    for i in "$@"; do
        if [[ ${i} -lt ${min} ]]; then
            min=${i}
        fi
    done
    echo "${min}"
}

validate_input() {
    # Validates the input values
    # $@: a list of values

    if [ $# -eq 0 ]; then
        echo "Error: No values provided"
        exit 1
    fi

    re='^[0-9]+$'
    for i in "$@"; do
        if ! [[ $i =~ $re ]]; then
            echo "Error: $i is not an integer"
            exit 1
        fi
    done
}

main() {
    validate_input "$@"
    find_minimum "$@"
}

main "$@"

