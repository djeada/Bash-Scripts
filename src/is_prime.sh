#!/usr/bin/env bash

# Script Name: is_prime.sh
# Description: Checks if a number is prime.
# Usage: is_prime.sh [<number>]
#        [<number>] - the number to check if it is a prime number.
# Example: ./is_prime.sh 5

is_prime() {

    a=$1

    if [[ $a -eq 2 ]] || [[ $a -eq 3 ]]; then
        return 1
    fi

    if [[ $(($a % 2)) -eq 0 ]] || [[ $(($a % 3)) -eq 0 ]]; then
        return 0
    fi

    i=3

    while [[ $((i * i)) -le $a ]]; do

        if [[ $(($a % i)) -eq 0 ]]; then
            return 0
        fi

        i=$((i + 2))
    done

    return 1
}


main() {

    if [ $# -ne 1 ]; then
        echo "Must provide exactly one number!"
        exit 1
    fi

    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]]; then
        echo "$1 is not a positive integer!"
        exit 1
    fi

    if [[ $(is_prime $1)$? -eq 1 ]]; then
        echo "$1 is a prime number!"
    else
        echo "$1 is not a prime number!"
    fi

}

main "$@"
