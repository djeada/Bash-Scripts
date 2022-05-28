#!/usr/bin/env bash

# Script Name: decimal_binary.sh
# Description: Converts decimal numbers to their binary representation.
# Usage: decimal_binary.sh [decimal_number]
#        [decimal_number] - decimal number to be converted to binary.
# Example: ./decimal_binary.sh 123

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

    echo "Conversion of a decimal number $1 to it's binary representation."

    number=$1
    reminder=1
    binary_representation=" "

    while [ "$number" -gt 0 ]
    do
        reminder=$(( number % 2))
        binary_representation="$binary_representation$reminder"
        number=$(( number / 2))
    done

    i=${#binary_representation}
    result=" "

    while [ "$i" -gt 0 ]
    do
        rev=$(echo "$binary_representation" | awk '{ printf substr( $0, "$i",1 ) }')
        result="$result$rev"
        i=$(( i - 1 ))
    done

    echo "Binary representation: $result"

}

main "$@"

