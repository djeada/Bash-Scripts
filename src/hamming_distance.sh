#!/usr/bin/env bash

# Script Name: hamming_distance.sh
# Description: Calculate the Hamming Distance of two strings.
# Usage: hamming_distance.sh string_a string_b
#        string_a - First string to compare
#        string_b - Second string to compare
# Example: hamming_distance.sh "xxbab" "wokka bbabb"
# Output: 4

calculate_hamming_distance() {
    local string_a="$1"
    local string_b="$2"
    local length=${#string_a}

    if (( length != ${#string_b} )); then
        echo "-1"
        return
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
        echo "Usage: hamming_distance.sh string_a string_b"
        return
    fi

    local string_a="$1"
    local string_b="$2"

    local distance=$(calculate_hamming_distance "$string_a" "$string_b")

    echo "The Hamming Distance between \"$string_a\" and \"$string_b\" is: $distance"
}

main "$@"

