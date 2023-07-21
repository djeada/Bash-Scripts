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

    # Using awk, FS sets the field separator to the character.
    # NF returns the number of fields (i.e., the number of occurrences of the character)
    # Subtract 1 because awk splits the string into fields,
    # thus creating an extra field. Subtracting 1 gives the number of occurrences of the character.
    local count=0
    count=$(awk -F"$character" '{print NF-1}' <<< "$string")

    echo "$count"
}

main() {
    # Check if exactly 2 arguments are provided
    if [[ $# -ne 2 ]]; then
        echo "Usage: count_char.sh [string] [character]"
        exit 1
    fi

    # Check if the character argument has exactly one character
    if [[ ${#2} -ne 1 ]]; then
        echo "Please provide a single character as the second argument."
        exit 1
    fi

    count_char "$1" "$2"
}

main "$@"

