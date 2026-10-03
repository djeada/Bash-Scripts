#!/usr/bin/env bash

# Script Name: rename_extension.sh
# Description: Renames the file extension of all files (recursively) in a given directory.
#              Extensions may be given with or without the leading dot. Existing files are never overwritten.
# Usage: ./rename_extension.sh <search directory> <extension> <new extension>
# Example: ./rename_extension.sh path/to/dir .txt .md

rename_extension() {
    # $1: file name
    # $2: old extension (with leading dot)
    # $3: new extension (with leading dot)

    local file_name="$1"
    local new_file_name="${file_name%"$2"}$3"

    if [ -e "$new_file_name" ]; then
        echo "Skipping $file_name: $new_file_name already exists" >&2
        return 1
    fi

    mv -- "$file_name" "$new_file_name" && echo "Renamed $file_name to $new_file_name"
}

rename_files_with_extension() {
    # $1: search directory
    # $2: extension
    # $3: new extension

    if [ $# -ne 3 ]; then
        echo "Usage: rename_extension.sh <search directory> <extension> <new extension>" >&2
        return 1
    fi

    local search_directory="$1"
    local extension=".${2#.}"
    local new_extension=".${3#.}"
    local status=0
    local file_name

    if [ ! -d "$search_directory" ]; then
        echo "Error: $search_directory is not a directory" >&2
        return 1
    fi

    while IFS= read -r -d '' file_name; do
        rename_extension "$file_name" "$extension" "$new_extension" || status=1
    done < <(find "$search_directory" -type f -name "*$extension" -print0)

    return "$status"
}

rename_files_with_extension "$@"

