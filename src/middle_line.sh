#!/usr/bin/env bash

# Script Name: middle_line.sh
# Description: Prints the middle line of a file.
# Usage: middle_line.sh file_name
#        file_name - the name of the file to print the middle line of.
# Example: ./middle_line.sh path/to/file.txt

main() {
    if [ $# -eq 0 ]; then
        echo "You must provide a file path!"
        exit 1
    fi

    file_path=$1

    if [ ! -f "$file_path" ]; then
        echo "$file_path is not a valid file path!"
        exit 1
    fi

    if [ ! -r "$file_path" ]; then
        echo "Cannot read $file_path!"
        exit 1
    fi

    if [ ! -s "$file_path" ]; then
        echo "$file_path is empty!"
        exit 1
    fi

    total_lines=$(wc -l <"$file_path")
    middle_line=$((total_lines / 2))

    while IFS= read -r line; do
        ((current_line++))
        if [ "$current_line" -eq "$middle_line" ]; then
            echo "$line"
            break
        fi
    done <"$file_path"
}

main "$@"

