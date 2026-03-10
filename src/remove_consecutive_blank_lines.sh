#!/bin/bash

# Script Name: remove_consecutive_blank_lines.sh
# Description: Removes repeated blank lines from files in a directory.
# Usage: remove_consecutive_blank_lines.sh directory
#        directory - the path to the directory containing the files to process.
# Example: ./remove_consecutive_blank_lines.sh /path/to/directory

validate_arguments() {
    # Validates the number of arguments provided
    # $1: directory
    if [ "$#" -ne 1 ]; then
        echo "Usage: $0 directory"
        exit 1
    fi
}

validate_directory() {
    # Validates if the provided path is a directory
    # $1: directory
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo "Error: '$dir' is not a directory."
        exit 1
    fi
}

remove_repeated_blank_lines() {
    # Removes repeated blank lines from files in the directory
    # $1: directory
    local dir="$1"

    find "$dir" -type f -print0 | while IFS= read -r -d $'\0' file; do
        awk 'BEGIN {RS="\n"; ORS="\n"; last_line=""} {if (NF == 0 && last_line == "") {next} else {print; last_line=$0}}' "$file" > "${file}.tmp"
        mv "${file}.tmp" "$file"
    done
}

main() {
    # Main function to orchestrate the script
    validate_arguments "$@"
    local dir="$1"
    validate_directory "$dir"
    remove_repeated_blank_lines "$dir"
    echo "Done. Repeated blank lines have been removed from files in the directory."
}

main "$@"

