#!/usr/bin/env bash

# Script Name: upper.sh
# Description: Converts a string to uppercase.
# Usage: upper.sh string
#        string - the string to convert to uppercase.
# Example: upper.sh 'Hello World'
# Output: HELLO WORLD

convert_to_uppercase() {
    # Converts a string to uppercase using tr
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

main() {
    # Main function to handle script logic

    # Check if exactly one argument is provided
    if [ "$#" -ne 1 ]; then
        echo "Error: Exactly one argument is required." >&2
        echo "Usage: upper.sh string" >&2
        exit 1
    fi

    # Call the convert_to_uppercase function with the provided argument
    convert_to_uppercase "$1"
}

# Call the main function with all passed arguments
main "$@"
