#!/usr/bin/env bash

# Script Name: factorial.sh
# Description: Calculates the factorial of a given non-negative integer (0-20; larger values overflow 64-bit arithmetic).
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
        echo "Must provide exactly one integer!" >&2
        exit 1
    fi

    if ! [[ $1 =~ ^[0-9]+$ ]]; then
        echo "$1 is not a non-negative integer!" >&2
        exit 1
    fi

    # Strip leading zeros (avoids octal parsing) and reject anything above 20,
    # since 21! no longer fits in a 64-bit integer.
    local number
    if [[ $1 =~ ^0*([0-9]{1,2})$ ]]; then
        number=$((10#${BASH_REMATCH[1]}))
    fi
    if [[ -z $number ]] || ((number > 20)); then
        echo "$1 is too large: factorials above 20! overflow 64-bit integers." >&2
        exit 1
    fi

    local result
    result=$(calculate_factorial "$number")

    echo "The factorial of $number is: $result"
}

main "$@"

