#!/usr/bin/env bash

# Script Name: count_char.sh
# Description: Counts the number of occurrences of a given character in a string.
# Usage: count_char.sh [string] [character]
#       [string] - The string to be searched.
#       [character] - The character to be searched for.
# Example: ./count_char.sh "Hello World" "o"
# Output: 2

count_char() {
    local string="$1"
    local character="$2"
    local count=0

    for (( i=0; i<${#string}; i++ )); do
        if [[ "${string:$i:1}" == "$character" ]]; then
            ((count++))
        fi
    done

    echo "$count"
}

main() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: count_char.sh [string] [character]"
        exit 1
    fi

    count_char "$1" "$2"
}

main "$@"

