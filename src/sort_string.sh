#!/usr/bin/env bash

# Script Name: sort_string.sh
# Description: Sorts the characters of a string (byte order, uppercase first);
#              whitespace is dropped.
# Usage: sort_string.sh string
#       string - a string to be sorted
# Example: sort_string.sh "Ala ma kota"
# Output: Aaaaklmot

validate_arguments() {
    if [ $# -ne 1 ]; then
        echo "Usage: sort_string.sh string" >&2
        echo "       string - a string to be sorted" >&2
        echo "Example: sort_string.sh \"Ala ma kota\"" >&2
        exit 1
    fi
}

sort_string() {
    local input_string="$1"
    local sorted_string
    sorted_string=$(printf '%s' "$input_string" | grep -o '[^[:space:]]' | LC_ALL=C sort | tr -d "\n")
    echo "$sorted_string"
}

main() {
    validate_arguments "$@"
    sort_string "$1"
}

main "$@"

