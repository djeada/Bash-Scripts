#!/usr/bin/env bash

# Script Name: are_anagrams.sh
# Description: Checks if two strings are anagrams of each other.
# Usage: are_anagrams.sh [string_a] [string_b]
#       [string_a] - First string to check.
#       [string_b] - Second string to check.
# Example: are_anagrams.sh "cat" "act"
# Output: true

sort_string() {
    local string=$1
    echo "$string" | tr -d ' ' | tr -d '\n' | tr -d '\t' | tr -d '\r' | grep -o . | sort | tr -d "\n"
}

are_angrams() {
    local string_a="$1"
    local string_b="$2"

    if [ ${#string_a} -ne ${#string_b} ]; then
        echo false
        return
    fi

    local string_a_sorted
    string_a_sorted=$(sort_string "$string_a")
    local string_b_sorted
    string_b_sorted=$(sort_string "$string_b")

    if [ "$string_a_sorted" == "$string_b_sorted" ]; then
        echo true
    else
        echo false
    fi
}


main() {

    if [ $# -ne 2 ]; then
        echo "Usage: hamming_distance.sh [string_a] [string_b]"
        return
    fi

    are_angrams "$1" "$2"
}

main "$@"

