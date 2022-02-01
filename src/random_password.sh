#!/usr/bin/env bash

# Script Name: random_password.sh
# Description: Script that generates a random password of the specified length.
# Usage: random_password.sh [n]
#       [n] - the length of the requested password
# Example: ./random_password.sh 15

main() {
    if [ $# -ne 1 ]; then
        echo "Usage: random_password.sh [n]"
        echo "       [n] - the length of the requested password"
        echo "Example: ./random_password.sh 15"
        exit 1
    fi

    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]]; then
        echo "Error: $1 is not an integer"
        exit 1
    fi

    password=$(strings /dev/urandom | grep -o '[[:alnum:]]' | head -n "$1" | tr -d '\n')
    echo "$password"

}

main "$@"
