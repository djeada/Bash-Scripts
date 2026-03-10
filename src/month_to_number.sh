#!/usr/bin/env bash

# Script Name: convert_month.sh
# Description: Converts between month names and numbers.
# Usage: convert_month.sh <month|number>
#        <month|number> - either a month name or a number
# Example: ./convert_month.sh 7
#          ./convert_month.sh jul

number_to_month() {
    # Converts a number to the corresponding month name
    # $1: an integer number

    # Check if exactly one argument is passed
    if [ $# -ne 1 ]; then
        echo "Error: exactly one argument is required"
        return 1
    fi

    # Check if the argument is an integer
    if ! [[ $1 =~ ^[0-9]+$ ]]; then
        echo "Error: argument must be an integer"
        return 1
    fi

    # Check if the argument is in the range of months
    if [ "$1" -lt 1 ] || [ "$1" -gt 12 ]; then
        echo "Error: argument must be in the range of months"
        return 1
    fi

    # Convert the number to the corresponding month
    local months=(jan feb mar apr may jun jul aug sep oct nov dec)
    echo "${months[$1-1]}"
}

month_to_number() {
    # Converts a month name to the corresponding number
    # $1: a month name

    # Check if exactly one argument is passed
    if [ $# -ne 1 ]; then
        echo "Error: exactly one argument is required"
        return 1
    fi

    # Check if the argument is a valid month name
    if ! [[ $1 =~ ^[a-z]+$ ]]; then
        echo "Error: argument must be a month name"
        return 1
    fi

    # Convert the month name to the corresponding number
    local months=(jan feb mar apr may jun jul aug sep oct nov dec)
    for i in "${!months[@]}"; do
        if [ "$1" = "${months[$i]}" ]; then
            echo $((i+1))
            return 0
        fi
    done

    # If the month name is not found
    echo "Error: argument must be a month name"
    return 1
}

main() {
    if [ $# -ne 1 ]; then
        # Exactly one argument is required: either month or number
        echo "Usage: $0 <month|number>"
        return 1
    fi

    if [[ $1 =~ ^[0-9]+$ ]]; then
        # If the argument is an integer, convert it to the corresponding month
        number_to_month "$1"
    else
        # If the argument is a month name, convert it to the corresponding number
        month_to_number "$1"
    fi
}

main "$@"

