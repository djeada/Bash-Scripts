#!/usr/bin/env bash

# Script Name: sqrt.sh
# Description: This script calculates the square root of a specified number.
#              (Newton's method, computed with bc).
# Usage: sqrt.sh number [precision]
#        number - The non-negative number to compute the square root for.
#        [precision] - The number of decimal places for rounding the result (optional, default 0).
# Example: ./sqrt.sh 16
# Output: 4

# Don't let bc wrap long results with backslash-newlines.
export BC_LINE_LENGTH=0

calculate_sqrt() {
    local number=$1
    local precision=$2
    # Work with a few extra digits so the final rounding is accurate.
    local scale
    scale=$((precision + 5))

    # Start from a guess >= 1 (number / 2 would be 0 or tiny for small inputs).
    local guess new_guess=0
    guess=$(bc -l <<< "if ($number > 1) $number / 2 else 1")

    while (( $(bc -l <<< "$number != 0") )); do
        new_guess=$(bc -l <<< "scale=$scale;($guess + $number / $guess) / 2")
        local difference
        difference=$(bc -l <<< "scale=$scale; $guess - $new_guess")

        if (( $(echo "$difference < 0" | bc -l) )); then
            difference=$(bc -l <<< "-1 * $difference")
        fi

        if (( $(bc -l <<< "scale=$scale; $difference < 10^-($scale - 1)") )); then
            break
        fi

        guess=$new_guess
    done

    # Round half up to the requested number of decimal places (bc's "/ 1" truncates).
    # Add a leading 0 for results below 1 (bc prints .5 instead of 0.5).
    bc -l <<< "scale=$scale; r = $new_guess + 5 * 10^-($precision + 1); scale=$precision; r / 1" | sed 's/^\./0./'
}

main() {
    if [[ $# -lt 1 || $# -gt 2 ]]; then
        {
            echo "Error: Invalid number of arguments provided."
            echo "Usage: sqrt.sh number [precision]"
            echo "       number - The non-negative number to compute the square root for."
            echo "       [precision] - The number of decimal places for rounding the result (optional)."
        } >&2
        exit 1
    fi

    local number="$1"
    local precision=0

    if [[ $# -eq 2 ]]; then
        precision="$2"
    fi

    if [[ ! $number =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "Error: The provided number ($number) is not a non-negative number!" >&2
        exit 1
    fi

    if [[ ! $precision =~ ^[0-9]+$ ]]; then
        echo "Error: The provided precision ($precision) is not a non-negative integer!" >&2
        exit 1
    fi

    if ! command -v bc >/dev/null 2>&1; then
        echo "Error: this script requires 'bc'." >&2
        exit 1
    fi

    calculate_sqrt "$number" "$precision"
}

main "$@"

