#!/usr/bin/env bash

# Script Name: lower.sh
# Description: Converts a string to lowercase.
# Usage: lower.sh string
#        string - the string to convert to lowercase.
# Example: lower.sh "Hello World"
# Output: hello world

convert_to_lowercase() {
    # Converts a string to lowercase
    # $1: string to convert

    # Check if exactly one argument is given
    if [ $# -ne 1 ]; then
        echo "Usage: lower.sh string"
        return 1
    fi

    # Use tr to convert the string to lowercase
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

main() {
    # Check if exactly one argument is provided
    if [ $# -ne 1 ]; then
        echo "Usage: lower.sh string"
        exit 1
    fi

    # Call the convert_to_lowercase function and pass the argument
    converted_string=$(convert_to_lowercase "$1")
    echo "$converted_string"
}

main "$@"
