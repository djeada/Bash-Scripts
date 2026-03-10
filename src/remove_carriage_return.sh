#!/usr/bin/env bash

# Script Name: remove_carriage_return.sh
# Description: Checks and removes the carriage return from all the files in a given directory.
# Usage: remove_carriage_return.sh [--check] directory_path
#        --check - When specified, script will only check if the files contain carriage returns without actually removing them
#        directory_path - the path to the directory to process.
# Example: ./remove_carriage_return.sh --check path/to/directory

checkonly=0
status=0

remove_carriage_return() {
    # Removes carriage return from a file
    # $1: file path
    local file="$1"

    if [[ $checkonly -ne 1 ]]; then
        sed -i 's/\r//g' "$file"
    else
        if grep -q $'\r' "$file"; then
            echo "File $file contains carriage return"
            return 1
        fi
    fi
}

process_directory() {
    # Processes all files in a directory
    # $1: directory path
    local directory="$1"

    while IFS= read -r -d $'\0' file; do
        remove_carriage_return "$file" && status=$? || status=$?
    done < <(find "$directory" -type f -print0)
}

process_single_file() {
    # Processes a single file
    # $1: file path
    local file="$1"

    remove_carriage_return "$file" && status=$? || status=$?
}

main() {
    # Main function to orchestrate the script

    if [[ $1 == "--check" ]]; then
        checkonly=1
        shift
    fi

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

    if [[ $checkonly -eq 1 && $status -eq 1 ]]; then
        echo "One or more files contain carriage return."
        exit 1
    fi

    echo "Carriage return checked successfully."
    exit 0
}

main "$@"

