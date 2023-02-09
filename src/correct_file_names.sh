#!/usr/bin/env bash

# Script Name: correct_file_names.sh
# Description: Corrects the file names in a given directory by replacing all non-alphanumeric characters 
#              (excluding dots) with underscores and converting repeated underscores to a single underscore. 
#              The names are also made lowercase.
# Usage: correct_file_names.sh [<directory>]
#       [<directory>] - the directory containing the files to be corrected.
# Example: ./correct_file_names.sh path/to/directory

correct_file_name ()
{
    new_name=$(echo "$1" | tr -s '' | tr '[:punct:]' '[:space:]' | tr -s ' ' | sed -e 's/ //g' | tr -s '_' | tr '[:upper:]' '[:lower:]')
    if [ "$1" != "$new_name" ]; then
        mv -T "$1" "$new_name"
    fi
}

find_files ()
{

    find "$1" -maxdepth 1 \( ! -regex '.*/\..*' \) | while read -r file
    do
        echo "$file"
        correct_file_name "$file"
        if [ "$1" != "$file" ] && [ -d "$file" ]; then
            find_files "$file"
        fi

    done

}

main() {

    if [ $# -eq 0 ]; then
        echo "Must provide a path!"
        exit 1
    fi

    if [ "$1" == '.' ] || [ -d "${1}" ]; then
        find_files "$1"
    elif [ -f "${1}" ]; then
        correct_file_name "$1"
    else
        echo "$1 is not a valid path!"
    fi

}

main "$@"

