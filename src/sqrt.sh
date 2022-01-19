#!/usr/bin/env bash

# Script Name: sqrt.sh
# Description: Script to calculate the square root of a number.
# Usage: sqrt.sh [number] [<precision>]
#       [number] - the number to calculate the square root of.
#       [<precision>] - the number of decimal places to round to.
# Example: ./sqrt.sh 16
# Output: 4

sqrt() {
    local number=$1
    local precision=$2
    local result="${number}.0"

    while [ 1 -eq $(echo "$result*$result - $number > 0.0001" | bc -l) ]; do
        result=$(echo "scale=$precision; ($result + $number/$result)/2" | bc -l)
    done

    echo $result
}


main() {

    if [ $# -ne 1 ] && [ $# -ne 2 ]; then
        echo "Must provide one or two arguments."
        exit 1
    fi

    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]]; then
        echo "$1 is not a positive integer!"
        exit 1
    fi

    local number=$1
    local precision=5

    if [ $# -eq 2 ]; then
        if ! [[ $2 =~ $re ]]; then
            echo "$2 is not a positive integer!"
            exit 1
        fi
        precision=$2
    fi

    sqrt $number $precision
}

main "$@"
