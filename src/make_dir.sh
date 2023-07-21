#!/usr/bin/env bash

# Script Name: make_dir.sh
# Description: Creates a directory and a file in it if the directory does not exist.
# Usage: make_dir.sh [directory_name] [file_name]
# Example: ./make_dir.sh my_directory my_file.txt

create_directory() {
    local dir_name="$1"

    if [[ ! -d "$dir_name" ]]; then
        mkdir -p "$dir_name" || { echo "Failed to create directory: $dir_name"; exit 1; }
        echo "Directory $dir_name created successfully."
    else
        echo "Directory $dir_name already exists."
    fi
}

create_file() {
    local file_name="$1"
    local file_content="$2"

    echo "$file_content" > "$file_name" || { echo "Failed to create file: $file_name"; exit 1; }
    echo "File $file_name created successfully."
}

main() {
    local dir_name="${1:-.}"
    local file_name="${2:-$(date +"%Y-%m-%d_%H-%M-%S").txt}"
    local file_content=""

    # Validate directory name
    create_directory "$dir_name"

    # Validate file name
    local full_file_path="$dir_name/$file_name"
    if [[ -f "$full_file_path" ]]; then
        read -rp "File $file_name already exists. Do you want to overwrite it? [Y/n]: " answer
        if [[ $answer != "Y" && $answer != "y" ]]; then
            echo "Aborted. File $file_name was not created."
            exit 0
        fi
    fi

    # Get file content from user
    echo "Enter the file content (press Ctrl+D to finish):"
    while IFS= read -r line; do
        file_content+="$line"$'\n'
    done

    # Create or overwrite file with content
    create_file "$full_file_path" "$file_content"
}

main "$@"

