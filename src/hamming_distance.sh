#!/usr/bin/env bash

# Script Name: hamming_distance.sh
# Description: Calculate the Hamming Distance of two strings.
# Usage: hamming_distance.sh string_a string_b
#        string_a - First string to compare
#        string_b - Second string to compare
# Example: hamming_distance.sh "xxbab" "bbabb"
# Output: 4

# Exit codes
EXIT_SUCCESS=0
EXIT_INVALID_ARGS=1
EXIT_DIFFERENT_LENGTHS=2

calculate_hamming_distance() {
    local string_a="$1"
    local string_b="$2"
    local length=${#string_a}

    if (( length != ${#string_b} )); then
        echo "Error: Strings have different lengths."
        exit $EXIT_DIFFERENT_LENGTHS
    fi

    local distance=0

    for ((i = 0; i < length; i++)); do
        if [[ "${string_a:i:1}" != "${string_b:i:1}" ]]; then
            (( distance++ ))
        fi
    done

    echo "$distance"
}

main() {
    if (( $# != 2 )); then
        echo "Error: Invalid number of arguments."
        echo "Usage: hamming_distance.sh string_a string_b"
        exit $EXIT_INVALID_ARGS
    fi

    local string_a="$1"
    local string_b="$2"

    local distance
    distance=$(calculate_hamming_distance "$string_a" "$string_b")
    if [[ $distance != *"Error"* ]]; then
        echo "The Hamming Distance between \"$string_a\" and \"$string_b\" is: $distance"
        exit $EXIT_SUCCESS
    fi
}

main "$@"
