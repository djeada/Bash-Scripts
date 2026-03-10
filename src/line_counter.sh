#!/usr/bin/env bash

# Script Name: line_counter.sh
# Description: Counts the number of lines in a file.
# Usage: line_counter.sh file_name
#        file_name - the name of the file to count the lines in.
# Example: ./line_counter.sh path/to/file.txt

validate_file() {
    # Validates if the file exists
    # $1: file path

    if [ ! -f "$1" ]; then
        echo "Error: $1 does not exist."
        exit 1
    fi
}

count_lines() {
    # Counts the number of lines in a file
    # $1: file path

    local counter=0

    while read -r _; do
        ((counter++))
    done < "$1"

    echo "$counter"
}

main() {
    # Main function to execute the script

    if [ $# -eq 0 ]; then
        echo "Error: No file name provided."
        echo "Usage: line_counter.sh file_name"
        exit 1
    fi

    local file_name="$1"

    validate_file "$file_name"

    local line_count=0
    line_count=$(count_lines "$file_name")

    echo "Number of lines in $file_name: $line_count"
}

main "$@"

