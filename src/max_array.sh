#!/usr/bin/env bash

# Script Name: max_array.sh
# Description: Find the maximum value in an array.
# Usage: max_array.sh [list of values]
#       [list of values] - a list of values separated by spaces
# Example: max_array.sh 4 5 6 1 2 3
# Output: 6

max_array() {
    local max=${1}
    shift
    for i in "${@}"; do
        if [[ ${i} -gt ${max} ]]; then
            max=${i}
        fi
    done
    echo "${max}"
}

main() {
    if [ $# -eq 0 ]; then
        echo "Usage: max_array.sh [list of values]"
        echo "       [list of values] - a list of values separated by spaces"
        echo "Example: max_array.sh 4 5 6 1 2 3"
        exit 1
    fi

    re='^[0-9]+$'
    for i in "$@"; do
        if ! [[ $i =~ $re ]]; then
            echo "Error: $i is not an integer"
            exit 1
        fi
    done

    max_array "${@}"
}

main "$@"
