#!/usr/bin/env bash

# Script Name: middle_line.sh
# Description: Prints the middle line of a file.
# Usage: middle_line.sh [<file_name>]
#        [<file_name>] - the name of the file to print the middle line of.
# Example: ./middle_line.sh path/to/file.txt

main() {
    if [ $# -eq 0 ]; then
        echo "You must provide a file path!"
        exit 1
    fi

    if [ ! -f "$1" ]; then
        echo "$1 is not a valid file path!"
        exit 1
    fi

    middle_line=$(($(sed -n '$=' "$1")/2))
    head -$middle_line "$1" | tail -n +$middle_line
}

main "$@"

