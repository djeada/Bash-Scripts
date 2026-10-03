#!/usr/bin/env bash

# Script Name: count_char.sh
# Description: Counts the number of occurrences of a given character in a string.
# Usage: count_char.sh string character
#        string - The string to be searched.
#        character - The character to be searched for.
# Example: ./count_char.sh 'Hello World' o
# Output: 2

# Function to count the number of occurrences of a character in a string
count_char() {
    local string="$1"
    local character="$2"

    # Delete every occurrence of the character (quoting the pattern makes it
    # literal, so '*', '.', ' ' etc. work), then compare the lengths.
    local stripped="${string//"$character"/}"

    echo $(( ${#string} - ${#stripped} ))
}

main() {
    # Check if exactly 2 arguments are provided
    if [[ $# -ne 2 ]]; then
        echo "Usage: count_char.sh [string] [character]" >&2
        exit 1
    fi

    # Check if the character argument has exactly one character
    if [[ ${#2} -ne 1 ]]; then
        echo "Please provide a single character as the second argument." >&2
        exit 1
    fi

    count_char "$1" "$2"
}

main "$@"

