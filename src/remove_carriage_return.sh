#!/usr/bin/env bash

# Script Name: remove_carriage_return.sh
# Description: Removes the carriage return from all the files in a given directory.
# Usage: remove_carriage_return.sh directory_path
#        directory_path - the path to the directory to process.
# Example: ./remove_carriage_return.sh path/to/directory

remove_carriage_return() {
    # Removes carriage return from a file
    # $1: file path
    sed -i 's/\r//g' "$1"
}

process_directory() {
    # Processes all files in a directory
    # $1: directory path
    local directory="$1"

    find "$directory" -type f -print0 | while IFS= read -r -d $'\0' file; do
        remove_carriage_return "$file"
    done
}

process_single_file() {
    # Processes a single file
    # $1: file path
    local file="$1"

    remove_carriage_return "$file"
}

main() {
    # Main function to orchestrate the script

    if [ $# -eq 0 ]; then
        echo "Must provide a path!"
        exit 1
    fi

    local path="$1"

    if [ "$path" == '.' ] || [ -d "$path" ]; then
        process_directory "$path"
    elif [ -f "$path" ]; then
        process_single_file "$path"
    else
        echo "$path is not a valid path!"
        exit 1
    fi

    echo "Carriage return removed successfully."
}

main "$@"
