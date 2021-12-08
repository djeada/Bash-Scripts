#!/usr/bin/env bash

# Script Name: sum_smaller_numbers.sh
# Description: Sums integers smaller than a given number.
# Usage: sum_smaller_numbers.sh [number]
#       [number] - the number to sum integers smaller than
# Example: ./sum_smaller_numbers.sh 10
# Output: The sum of integers smaller than 10 is 45

sum() {
    local sum=0
    local i=0
    while [ $i -lt $1 ]; do
        ((sum += i))
        ((i++))
    done
    echo $sum
}

main() {
    if [ $# -ne 1 ]; then
        echo "Usage: sum_smaller_numbers.sh [number]"
        echo "       [number] - the number to sum integers smaller than"
        exit 1
    fi

    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]] ; then
        echo "You must provide a positive integer."
        exit 1
    fi

    echo "Sum of integers smaller than $1 is $(sum $1)."
}

main "$@"
