#!/usr/bin/env bash

# Script Name: hamming_distance.sh
# Description: Calculate the Hamming Distance of two strings of equal length.
# Usage: hamming_distance.sh string_a string_b
#        string_a - First string to compare
#        string_b - Second string to compare
# Exit codes: 0 success, 1 invalid arguments, 2 strings of different lengths
# Example: hamming_distance.sh "xxbab" "bbabb"
# Output: The Hamming Distance between "xxbab" and "bbabb" is: 4

# Exit codes
EXIT_INVALID_ARGS=1
EXIT_DIFFERENT_LENGTHS=2

calculate_hamming_distance() {
    local string_a="$1"
    local string_b="$2"
    local length=${#string_a}
    local distance=0
    local i

    for ((i = 0; i < length; i++)); do
        if [[ "${string_a:i:1}" != "${string_b:i:1}" ]]; then
            distance=$((distance + 1))
        fi
    done

    echo "$distance"
}

main() {
    if (( $# != 2 )); then
        echo "Error: Invalid number of arguments." >&2
        echo "Usage: hamming_distance.sh string_a string_b" >&2
        exit $EXIT_INVALID_ARGS
    fi

    local string_a="$1"
    local string_b="$2"

    if (( ${#string_a} != ${#string_b} )); then
        echo "Error: Strings have different lengths." >&2
        exit $EXIT_DIFFERENT_LENGTHS
    fi

    echo "The Hamming Distance between \"$string_a\" and \"$string_b\" is: $(calculate_hamming_distance "$string_a" "$string_b")"
}

main "$@"

