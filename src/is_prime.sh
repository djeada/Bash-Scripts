#!/usr/bin/env bash

# Script Name: is_prime.sh
# Description: Checks if a number is prime.
# Usage: is_prime.sh number
#        number - the non-negative integer (at most 18 digits) to check.
# Example: ./is_prime.sh 5

is_prime() {
    local num=$1
    local i

    if (( num < 2 )); then
        return 1
    fi

    if (( num == 2 )); then
        return 0
    fi

    if (( num % 2 == 0 )); then
        return 1
    fi

    # Only odd divisors up to sqrt(num) need to be tried
    for ((i = 3; i * i <= num; i += 2)); do
        if (( num % i == 0 )); then
            return 1
        fi
    done

    return 0
}

main() {
    if [ $# -ne 1 ]; then
        echo "Usage: is_prime.sh number" >&2
        exit 1
    fi

    # Limit to 18 digits so the value fits in Bash's 64-bit integers
    re='^[0-9]{1,18}$'
    if ! [[ $1 =~ $re ]]; then
        echo "$1 is not a non-negative integer (max 18 digits)!" >&2
        exit 1
    fi

    # Force base 10 so leading zeros (e.g. 08) aren't parsed as octal
    local num=$((10#$1))

    if is_prime "$num"; then
        echo "$num is a prime number!"
    else
        echo "$num is not a prime number!"
    fi
}

main "$@"

