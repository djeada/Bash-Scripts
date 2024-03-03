#!/usr/bin/env bash

# Script Name: lower.sh
# Description: Converts a string to lowercase.
# Usage: lower.sh string
#        string - the string to convert to lowercase.
# Example: lower.sh "Hello World"
# Output: hello world

convert_to_lowercase() {
    # Converts a string to lowercase using tr
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

main() {
    # Main function to handle script logic

    # Check if exactly one argument is provided
    if [ "$#" -ne 1 ]; then
        echo "Error: Exactly one argument is required." >&2
        echo "Usage: lower.sh string" >&2
        exit 1
    fi

    # Call the convert_to_lowercase function with the provided argument
    convert_to_lowercase "$1"
}

# Call the main function with all passed arguments
main "$@"
