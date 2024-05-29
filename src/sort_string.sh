#!/usr/bin/env bash

# Script Name: sort_string.sh
# Description: Sorts a string alphabetically.
# Usage: sort_string.sh string
#       string - a string to be sorted
# Example: sort_string.sh "Ala ma kota"
# Output: Aaaaklmot

validate_arguments() {
    if [ $# -ne 1 ]; then
        echo "Usage: sort_string.sh string"
        echo "       string - a string to be sorted"
        echo "Example: sort_string.sh \"Ala ma kota\""
        exit 1
    fi
}

sort_string() {
    local input_string="$1"
    local sorted_string
    sorted_string=$(echo "$input_string" | grep -o . | sort | tr -d "\n")
    echo "$sorted_string"
}

main() {
    validate_arguments "$@"
    sort_string "$1"
}

main "$@"
