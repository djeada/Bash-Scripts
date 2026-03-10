#!/bin/bash

rename_extension() {
    # $1: file name
    # $3: new extension

    # the number of arguments must be 2
    if [ $# -ne 2 ]; then
        echo "Usage: rename_extension <file name> <new extension>"
        return 1
    fi

    local file_name="$1"
    local new_extension="$2"
    local old_extension
    local new_file_name

    old_extension=$([[ "$file_name" = *.* ]] && echo ".${file_name##*.}" || echo '')
    new_file_name="${file_name%"$old_extension"}$new_extension"

    mv "$file_name" "$new_file_name"
    echo "Renamed $file_name to $new_file_name"
}


find_files_with_extension() {
    # $1: search directory
    # $2: extension

    # the number of arguments must be 1
    if [ $# -ne 2 ]; then
        echo "Usage: find_files_with_extension <search directory> <extension>"
        return 1
    fi

    local search_directory="$1"
    local extension="$2"

    find "$search_directory" -type f -name "*$extension"
}


rename_files_with_extension() {
    # $1: search directory
    # $2: extension
    # $3: new extension

    # the number of arguments must be 2
    if [ $# -ne 3 ]; then
        echo "Usage: rename_files_with_extension <search directory> <extension> <new extension>"
        return 1
    fi

    local search_directory="$1"
    local extension="$2"
    local new_extension="$3"

    find_files_with_extension "$search_directory" "$extension" | while read -r file_name; do
        rename_extension "$file_name" "$new_extension"
    done
}


rename_files_with_extension "$@"

