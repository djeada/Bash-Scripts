#!/usr/bin/env bash

# Script Name: max_array.sh
# Description: Find the maximum value in an array.
# Usage: max_array.sh val1 val2 ...
#        val1 val2 ... - a list of values separated by spaces
# Example: max_array.sh 4 5 6 1 2 3
# Output: 6

find_maximum() {
    # Finds the maximum value in an array
    # $@: a list of values

    local max=${1}
    shift
    for i in "$@"; do
        if [[ ${i} -gt ${max} ]]; then
            max=${i}
        fi
    done
    echo "${max}"
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
    find_maximum "$@"
}

main "$@"

