#!/usr/bin/env bash

# Script Name: assert_last_line_empty.sh
# Description: Checks if the last line of a file is empty and appends an empty line if it's not.
# Usage: assert_last_line_empty.sh [--check] <file_path>
#        --check - When specified, script will only check if the last line is empty without actually appending a new line
#        <file_path> - the path to the file to be processed.
# Example: ./assert_last_line_empty.sh --check path/to/file.txt

checkonly=0
status=0

assert_last_line_empty() {
    local file="$1"
    local last_line

    echo "Checking if the last line of ${file} is empty..."

    last_line=$(tail -n 1 "${file}")

    if [ -z "${last_line}" ]; then
        echo "Last line is empty!"
    else
        echo "Last line is not empty!"
        if [[ $checkonly -ne 1 ]]; then
            echo "" >> "${file}"
            echo "An empty line has been appended."
        else
            echo "${file} requires an empty line at the end"
            status=1
        fi
    fi
}

process_file() {
    local file="$1"

    if [ ! -f "${file}" ]; then
        echo "Error: ${file} is not a regular file."
        return 1
    fi

    assert_last_line_empty "${file}"
}

process_directory() {
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
    if [ $# -eq 0 ]; then
        echo "Error: No path provided."
        echo "Usage: assert_last_line_empty.sh [--check] <file_path>"
        exit 1
    fi

    if [[ $1 == "--check" ]]; then
        checkonly=1
        shift
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

    if [[ $status -eq 1 ]]; then
        exit 1
    fi
}

main "$@"

