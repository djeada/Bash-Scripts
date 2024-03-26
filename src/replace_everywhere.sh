#!/usr/bin/env bash

# Script Name: replace_everywhere.sh
# Description: Replace string a with string b in all files in the current directory and all subdirectories.
# Usage: replace_everywhere.sh [string_a] [string_b]
#       [string_a] - Old string.
#       [string_b] - New string.
# Example: replace_everywhere.sh "cat" "dog"
#
# For strings with spaces or special characters, use single quotes:
# replace_everywhere.sh 'string with space' 'new string'
# replace_everywhere.sh 'string\*\*' 'new\string'

print_usage() {
    echo "Usage: replace_everywhere.sh [string_a] [string_b]"
    echo "       [string_a] - Old string."
    echo "       [string_b] - New string."
}

escape_string() {
    printf '%s' "$1" | sed 's:[][\/.^$*]:\\&:g'
}

main() {
    if [ $# -ne 2 ]; then
        print_usage
        return 1
    fi

    local search replace
    search=$(escape_string "$1")
    replace=$(escape_string "$2")

    # Confirm action
    read -r -p "Are you sure you want to replace all occurrences of '$1' with '$2'? [y/N] " confirmation
    if [[ ! $confirmation =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        return 1
    fi

    # Perform the replacement
    find . -type f -exec sed -i "s/$search/$replace/g" {} \;
}

main "$@"
