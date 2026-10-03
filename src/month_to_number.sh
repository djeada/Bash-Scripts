#!/usr/bin/env bash

# Script Name: month_to_number.sh
# Description: Converts between month names and numbers.
# Usage: month_to_number.sh <month|number>
#        <month|number> - a month name, full or three-letter (case-insensitive), or a number from 1 to 12
# Example: ./month_to_number.sh 7
#          ./month_to_number.sh jul
#          ./month_to_number.sh January

MONTHS=(jan feb mar apr may jun jul aug sep oct nov dec)
FULL_MONTHS=(january february march april may june july august september october november december)

number_to_month() {
    # Converts a number to the corresponding month name
    # $1: an integer number

    # Check if exactly one argument is passed
    if [ $# -ne 1 ]; then
        echo "Error: exactly one argument is required" >&2
        return 1
    fi

    # Check if the argument is an integer
    if ! [[ $1 =~ ^[0-9]+$ ]]; then
        echo "Error: argument must be an integer" >&2
        return 1
    fi

    # Force base 10 so that e.g. "08" is not parsed as an invalid octal number
    local number=$((10#$1))

    # Check if the argument is in the range of months
    if [ "$number" -lt 1 ] || [ "$number" -gt 12 ]; then
        echo "Error: argument must be in the range of months" >&2
        return 1
    fi

    # Convert the number to the corresponding month
    echo "${MONTHS[number-1]}"
}

month_to_number() {
    # Converts a month name to the corresponding number
    # $1: a month name

    # Check if exactly one argument is passed
    if [ $# -ne 1 ]; then
        echo "Error: exactly one argument is required" >&2
        return 1
    fi

    local month="${1,,}"

    # Convert the month name to the corresponding number
    for i in "${!MONTHS[@]}"; do
        if [ "$month" = "${MONTHS[$i]}" ] || [ "$month" = "${FULL_MONTHS[$i]}" ]; then
            echo $((i+1))
            return 0
        fi
    done

    # If the month name is not found
    echo "Error: argument must be a month name" >&2
    return 1
}

main() {
    if [ $# -ne 1 ]; then
        # Exactly one argument is required: either month or number
        echo "Usage: $0 <month|number>" >&2
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

