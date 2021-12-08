#!/usr/bin/env bash

# Script Name: sort_string.sh
# Description: Sorts a string alphabetically.
# Usage: sort_string.sh [string]
#       [string] - a string to be sorted
# Example: sort_string.sh "Ala ma kota"
# Output: Aaaaklmot  

sort_string() {
    echo "$1" |  grep -o . | sort -V | tr -d "\n"
    echo
}

main() {
    if [ $# -ne 1 ]; then
        echo "Usage: sort_string.sh [string]"
        echo "       [string] - a string to be sorted"
        echo "Example: sort_string.sh \"Ala ma kota\""
        exit 1
    fi

    sort_string "$1"
}

main "$@"
