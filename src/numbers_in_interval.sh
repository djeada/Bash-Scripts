#!/usr/bin/env bash

# Script Name: numbers_in_interval.sh
# Description: Script to print all numbers in a given interval (inclusive), one per line.
# Usage: numbers_in_interval.sh [start] [end]
#        [start] - start of the interval (non-negative integer)
#        [end] - end of the interval (non-negative integer, >= start)
# Example: ./numbers_in_interval.sh 1 5
# Output: 1 2 3 4 5 (each on its own line)

print_numbers_in_interval() {
    local start=$1
    local end=$2

    for ((i = start; i <= end; i++)); do
        echo "$i"
    done
}

main() {

    if [ $# -ne 2 ]; then
        echo "Usage: numbers_in_interval.sh [start] [end]" >&2
        exit 1
    fi

    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]] || ! [[ $2 =~ $re ]]; then
        echo "Both arguments must be non-negative integers" >&2
        exit 1
    fi

    # Force base 10 so values with leading zeros (e.g. 08) are not read as octal
    local start=$((10#$1))
    local end=$((10#$2))

    if [ "$start" -gt "$end" ]; then
        echo "Start must not be greater than end" >&2
        exit 1
    fi

    print_numbers_in_interval "$start" "$end"
}

main "$@"

