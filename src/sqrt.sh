#!/usr/bin/env bash

# Script Name: sqrt.sh
# Description: This script calculates the square root of a specified number.
# Usage: sqrt.sh number precision
#        number - The number to compute the square root for.
#        [precision] - The number of decimal places for rounding the result (optional).
# Example: ./sqrt.sh 16
# Output: 4

calculate_sqrt() {
    local number=$1
    local precision=$2
    local scale
    scale=$((precision + 1))
    local guess
    guess=$(bc -l <<< "$number / 2")

    while true; do
        local new_guess
        new_guess=$(bc -l <<< "scale=$scale;($guess + $number / $guess) / 2")
        local difference
        difference=$(bc -l <<< "scale=$scale; $guess - $new_guess")

        if (( $(echo "$difference < 0" | bc -l) )); then
            difference=$(bc -l <<< "-1 * $difference")
        fi

        if (( $(echo "$difference < 1 * 10^-$scale" | bc -l) )); then
            break
        fi

        guess=$new_guess
    done

    # Use bc to round the result
    bc -l <<< "scale=$precision; $new_guess / 1"
}

main() {
    if [[ $# -lt 1 || $# -gt 2 ]]; then
        echo "Error: Invalid number of arguments provided."
        echo "Usage: sqrt.sh number [precision]"
        echo "       number - The number to compute the square root for."
        echo "       [precision] - The number of decimal places for rounding the result (optional)."
        exit 1
    fi

    local number="$1"
    local precision=0

    if [[ $# -eq 2 ]]; then
        precision="$2"
    fi

    if [[ ! $number =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "Error: The provided number ($number) is not a positive number!"
        exit 1
    fi

    if [[ ! $precision =~ ^[0-9]+$ ]]; then
        echo "Error: The provided precision ($precision) is not a positive integer!"
        exit 1
    fi

    local result
    result=$(calculate_sqrt "$number" "$precision")
    echo "$result"
}

main "$@"


