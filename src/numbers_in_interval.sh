#!/usr/bin/env bash

# Script Name: numbers_in_interval.sh
# Description: Script to print all numbers in a given interval.
# Usage: numbers_in_interval.sh [start] [end]
#        [start] - start of the interval
#        [end] - end of the interval
# Example: ./numbers_in_interval.sh 1 5
# Output: 1 2 3 4 5

print_numbers_in_interval() {
    local start=$1
    local end=$2

    for ((i = start; i <= end; i++)); do
        echo "$i"
    done
}

main() {

    if [ $# -ne 2 ]; then
        echo "Usage: numbers_in_interval.sh [start] [end]"
        exit 1
    fi

    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]] || ! [[ $2 =~ $re ]]; then
        echo "Both arguments must be positive integers"
        exit 1
    fi

    if [ "$1" -ge "$2" ]; then
        echo "Start must be less than end"
        exit 1
    fi

    print_numbers_in_interval "$1" "$2"
}

main "$@"

