#!/usr/bin/env bash

# Script Name: are_anagrams.sh
# Description: Checks if two strings are anagrams of each other. Ignores case, spaces and line breaks.
# Usage: are_anagrams.sh string_a string_b
#        string_a - First string to check.
#        string_b - Second string to check.
# Example: are_anagrams.sh "cat" "act"
# Output: The strings are anagrams.

# Function to clean and sort a string
sort_string() {
    local string=$1
    echo "$string" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | grep -o . | sort | tr -d "\n"
}

# Function to compare two strings and decide if they are anagrams
are_anagrams() {
    local string_a="$1"
    local string_b="$2"

    # Check if strings have the same length after removing spaces
    if [ ${#string_a} -ne ${#string_b} ]; then
        echo "The strings are not anagrams."
        return
    fi

    # Sort strings
    local string_a_sorted=$(sort_string "$string_a")
    local string_b_sorted=$(sort_string "$string_b")

    # Compare sorted strings
    if [ "$string_a_sorted" == "$string_b_sorted" ]; then
        echo "The strings are anagrams."
    else
        echo "The strings are not anagrams."
    fi
}

# Main function to control the flow of the script
main() {
    # Check if exactly two arguments are given
    if [ $# -ne 2 ]; then
        echo "Error: Invalid number of arguments."
        echo "Usage: are_anagrams.sh string_a string_b"
        return
    fi

    are_anagrams "$1" "$2"
}

main "$@"

