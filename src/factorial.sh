#!/usr/bin/env bash

# Script Name: factorial.sh
# Description: Calculates the factorial of a given integer.
# Usage: factorial.sh integer
#        integer - Integer to calculate the factorial of.
# Example: ./factorial.sh 5

calculate_factorial() {
    local num=$1
    local fact=1

    while ((num > 1)); do
        fact=$((fact * num))
        num=$((num - 1))
    done

    echo "$fact"
}

main() {
    if (( $# != 1 )); then
        echo "Must provide exactly one integer!"
        exit 1
    fi

    if ! [[ $1 =~ ^[0-9]+$ ]]; then
        echo "$1 is not a positive integer!"
        exit 1
    fi

    local number=$1
    local result='-1'
    result=$(calculate_factorial "$number")

    echo "The factorial of $number is: $result"
}

main "$@"

