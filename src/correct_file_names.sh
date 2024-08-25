#!/usr/bin/env bash

# Script Name: correct_file_names.sh
# Description: This script corrects file names in a specified directory by replacing all non-alphanumeric characters
#              (excluding dots) with underscores, converting repeated underscores to a single underscore, and making the names lowercase.
#              Additionally, it provides an option to include hidden directories and an option to exclude certain files from being changed.
# Usage: correct_file_names.sh [-a] [-e file1,file2,...] <directory>
#        -a: Include hidden directories (default is false).
#        -e: Comma-separated list of file names to exclude from changes (default is "README.md").
#        <directory>: The directory containing the files to be corrected.
# Example: ./correct_file_names.sh -a -e README.md,example.txt path/to/directory

correct_file_name() {
    local old_name="$1"
    local new_name

    # Replace all punctuation characters with underscores
    new_name=$(echo "$old_name" | sed -e 's/[^a-zA-Z0-9._\/]/_/g')

    # Replace all repeated underscores with a single underscore
    new_name=$(echo "$new_name" | tr -s '_')

    # Convert the name to lowercase
    new_name=$(echo "$new_name" | tr '[:upper:]' '[:lower:]')

    # Remove leading underscores
    new_name=$(echo "$new_name" | sed -e 's/^_//g')

    # Remove trailing underscores
    new_name=$(echo "$new_name" | sed -e 's/_$//g')

    if [ "$old_name" != "$new_name" ]; then
        mv -T "$old_name" "$new_name"
    fi
}

find_files() {
    local dir="$1"
    local include_hidden="$2"
    local exclusions="$3"
    local find_options="-maxdepth 1"
    
    if [ "$include_hidden" != true ]; then
        find_options="$find_options \( ! -regex '.*/\..*' \)"
    fi

    find "$dir" $find_options -print0 | while IFS= read -r -d $'\0' file; do
        local base_file=$(basename "$file")
        if [[ ! "$exclusions" =~ (^|,)$base_file(,|$) ]]; then
            correct_file_name "$file"
        fi
        if [ "$dir" != "$file" ] && [ -d "$file" ]; then
            find_files "$file" "$include_hidden" "$exclusions"
        fi
    done
}

main() {
    local include_hidden=false
    local exclusions="README.md"

    while getopts ":ae:" opt; do
        case $opt in
            a)
                include_hidden=true
                ;;
            e)
                exclusions="$exclusions,$OPTARG"
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
        esac
    done
    shift $((OPTIND - 1))

    if [ $# -eq 0 ]; then
        echo "Usage: $0 [-a] [-e file1,file2,...] <directory>"
        exit 1
    fi

    local dir="$1"

    if [ "$dir" == '.' ] || [ -d "$dir" ]; then
        find_files "$dir" "$include_hidden" "$exclusions"
    elif [ -f "$dir" ]; then
        local base_file=$(basename "$dir")
        if [[ ! "$exclusions" =~ (^|,)$base_file(,|$) ]]; then
            correct_file_name "$dir"
        fi
    else
        echo "$dir is not a valid path!"
        exit 1
    fi
}

main "$@"
