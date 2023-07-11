#!/usr/bin/env bash

# Script Name: assert_last_line_empty.sh
# Description: Checks if the last line of a file is empty and appends an empty line if it's not.
# Usage: assert_last_line_empty.sh <file_path>
#        <file_path> - the path to the file to be processed.
# Example: ./assert_last_line_empty.sh path/to/file.txt

assert_last_line_empty() {
    # Checks if the last line of the file is empty and appends an empty line if it's not.
    # $1: file path

    local file="$1"

    echo "Checking if the last line of ${file} is empty..."

    local last_line=$(tail -n 1 "${file}")

    if [ -z "${last_line}" ]; then
        echo "Last line is empty!"
    else
        echo "Last line is not empty!"
        echo "" >> "${file}"
        echo "An empty line has been appended."
    fi
}

process_file() {
    # Processes a single file by calling the assert_last_line_empty function.
    # $1: file path

    local file="$1"

    if [ ! -f "${file}" ]; then
        echo "Error: ${file} is not a regular file."
        return 1
    fi

    assert_last_line_empty "${file}"
}

process_directory() {
    # Processes all files in a directory (including subdirectories) by calling the process_file function.
    # $1: directory path

    local directory="$1"

    if [ ! -d "${directory}" ]; then
        echo "Error: ${directory} is not a directory."
        return 1
    fi

    echo "Processing files in ${directory}..."

    while IFS= read -r -d '' file; do
        process_file "${file}"
    done < <(find "${directory}" -type f -print0)
}

main() {
    # Main function to execute the script

    if [ $# -eq 0 ]; then
        echo "Error: No path provided."
        echo "Usage: assert_last_line_empty.sh <file_path>"
        exit 1
    elif [ $# -gt 1 ]; then
        echo "Error: Only one path is supported."
        exit 1
    fi

    local path="$1"

    if [ -d "${path}" ]; then
        process_directory "${path}"
    elif [ -f "${path}" ]; then
        process_file "${path}"
    else
        echo "Error: ${path} is not a valid file or directory."
        exit 1
    fi
}

main "$@"
