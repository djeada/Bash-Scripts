#!/usr/bin/env bash

# Script Name: arith_mean.sh
# Description: Script to calculate arithmetic mean of a list of numbers
# Usage: arith_mean.sh [list of numbers]
#       [list of numbers] - space separated list of numbers
# Example: ./arith_mean.sh 1 2 3 4 5

mean() {
    local sum=0
    local count=0
    while [ $# -gt 0 ]; do
        sum=$((sum + $1))
        count=$((count + 1))
        shift
    done
    echo $((sum / count))
}

main() {
    if [ $# -eq 0 ]; then
        echo "Usage: arith_mean.sh [list of numbers]"
        echo "       [list of numbers] - space separated list of numbers"
        echo "Example: arith_mean.sh 1 2 3 4 5"
        exit 1
    fi

    re='^[0-9]+$'
    for i in $@; do
        if ! [[ $i =~ $re ]]; then
            echo "Error: $i is not an integer"
            exit 1
        fi
    done

    echo "Arithmetic mean of $@ is $(mean $@)"
}

main "$@"