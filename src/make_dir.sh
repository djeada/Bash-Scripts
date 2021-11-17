#!/usr/bin/env bash

# Script Name: make_dir.sh
# Description: Creates a directory and a file in it if the directory does not exist.
# Usage: make_dir.sh
# Example: ./make_dir.sh

main() {

    echo "Enter the directory name:"

    read dir_name

    if [[ -d "$dir_name" ]]; then
        echo "Directory $dir_name already exists."
        exit 1
    fi

    if [[ ! -d "$dir_name" ]]; then
        mkdir -p "$dir_name"
    fi

    echo "Enter the file name:"

    read file_name

    file_name="$dir_name/$file_name"

    if [[ ! -f "$file_name" ]]; then
        touch "$file_name"
    fi

    echo "Enter the file content:"

    read file_content

    echo "$file_content" >> "$file_name"

    echo "Directory $dir_name created successfully."
    echo "File $file_name created within $dir_name."

}

main "$@"
