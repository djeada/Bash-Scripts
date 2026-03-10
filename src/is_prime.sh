#!/usr/bin/env bash

# Script Name: is_prime.sh
# Description: Checks if a number is prime.
# Usage: is_prime.sh number
#        number - the number to check if it is a prime number.
# Example: ./is_prime.sh 5

is_prime() {
    local num=$1

    if [[ $num -lt 2 ]]; then
        return 1
    fi

    if [[ $num -eq 2 ]]; then
        return 0
    fi

    if [[ $((num % 2)) -eq 0 ]]; then
        return 1
    fi

    local sqrt='-1'
    sqrt=$(echo "sqrt($num)" | bc)
    sqrt=${sqrt%.*}  # Remove decimal part

    for ((i = 3; i <= sqrt; i += 2)); do
        if [[ $((num % i)) -eq 0 ]]; then
            return 1
        fi
    done

    return 0
}

main() {
    if [ $# -ne 1 ]; then
        echo "Usage: is_prime.sh number"
        exit 1
    fi

    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]]; then
        echo "$1 is not a positive integer!"
        exit 1
    fi

    if [[ $1 -eq 1 ]]; then
        echo "$1 is not a prime number!"
        exit 0
    fi

    if is_prime "$1"; then
        echo "$1 is a prime number!"
    else
        echo "$1 is not a prime number!"
    fi
}

main "$@"

