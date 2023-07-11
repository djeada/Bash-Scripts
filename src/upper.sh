#!/usr/bin/env bash

# Script Name: upper.sh
# Description: Converts a string to uppercase.
# Usage: upper.sh string
#        string - the string to convert to uppercase.
# Example: upper.sh "Hello World"
# Output: HELLO WORLD

convert_to_uppercase() {
    # Converts a string to uppercase
    # $1: string to convert

    # Check if exactly one argument is given
    if [ $# -ne 1 ]; then
        echo "Usage: upper.sh string"
        return 1
    fi

    # Use tr to convert the string to uppercase
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

main() {
    # Check if exactly one argument is provided
    if [ $# -ne 1 ]; then
        echo "Usage: upper.sh string"
        exit 1
    fi

    # Call the convert_to_uppercase function and pass the argument
    converted_string=$(convert_to_uppercase "$1")
    echo "$converted_string"
}

main "$@"
