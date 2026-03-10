#!/usr/bin/env bash

# Script Name: sum_smaller_numbers.sh
# Description: Sums integers smaller than a given number.
# Usage: sum_smaller_numbers.sh number
#        number - the number to sum integers smaller than
# Example: ./sum_smaller_numbers.sh 10
# Output: The sum of integers smaller than 10 is 45

validate_arguments() {
    if [ $# -ne 1 ]; then
        echo "Usage: sum_smaller_numbers.sh number"
        echo "       number - the number to sum integers smaller than"
        exit 1
    fi

    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]]; then
        echo "You must provide a positive integer."
        exit 1
    fi
}

calculate_sum() {
    local number="$1"
    local sum=0
    local i=0

    while [ "$i" -lt "$number" ]; do
        ((sum += i))
        ((i++))
    done

    echo "$sum"
}

main() {
    validate_arguments "$@"

    local number="$1"

    local sum=0
    sum=$(calculate_sum "$number")

    echo "The sum of integers smaller than $number is $sum."
}

main "$@"

