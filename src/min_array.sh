#!/usr/bin/env bash

# Script Name: min_array.sh
# Description: Find the minimum value in an array.
# Usage: min_array.sh [list of values]
#       [list of values] - a list of values separated by spaces
# Example: min_array.sh 4 5 6 1 2 3
# Output: 1

min_array() {
    local min=${1}
    shift
    for i in "${@}"; do
        if [[ ${i} -lt ${min} ]]; then
            min=${i}
        fi
    done
    echo "${min}"
}

main() {
    if [ $# -eq 0 ]; then
        echo "Usage: min_array.sh [list of values]"
        echo "       [list of values] - a list of values separated by spaces"
        echo "Example: min_array.sh 4 5 6 1 2 3"
        exit 1
    fi

    re='^[0-9]+$'
    for i in "$@"; do
        if ! [[ $i =~ $re ]]; then
            echo "Error: $i is not an integer"
            exit 1
        fi
    done

    min_array "${@}"
}

main "$@"
