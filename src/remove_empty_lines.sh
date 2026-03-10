#!/usr/bin/env bash

# Script Name: remove_empty_lines.sh
# Description: Removes all that contain only whitespaces in a given file.
# Usage: remove_empty_lines.sh [<file_path>]
#        [<file_path>] - the path to the file to process.
# Example: ./remove_empty_lines.sh path/to/file

main() {
    if [ $# -eq 0 ]; then
        echo "You must provide a file path!"
        exit 1
    fi

    if [ ! -f "$1" ]; then
        echo "$1 is not a valid file path!"
        exit 1
    fi

    local file_path=$1
    local file_name
    file_name=$(basename "$file_path")
    temp_name="$file_name""$(date '+%Y-%m-%d')".tmp

    awk 'NF' "$file_path" > "$temp_name"
    mv "$temp_name" "$file_path"

}

main "$@"

