#!/usr/bin/env bash

# Script Name: make_dir.sh
# Description: Creates a directory (if it does not already exist) and a file in it,
#              filled with content typed on standard input.
# Usage: make_dir.sh [directory_name] [file_name]
#        directory_name defaults to '.', file_name to a timestamp (YYYY-MM-DD_HH-MM-SS.txt).
# Example: ./make_dir.sh my_directory my_file.txt

create_directory() {
    local dir_name="$1"

    if [[ ! -d "$dir_name" ]]; then
        mkdir -p -- "$dir_name" || { echo "Failed to create directory: $dir_name" >&2; exit 1; }
        echo "Directory $dir_name created successfully."
    else
        echo "Directory $dir_name already exists."
    fi
}

create_file() {
    local file_name="$1"

    # Copy standard input verbatim (keeps a last line without trailing newline)
    cat > "$file_name" || { echo "Failed to create file: $file_name" >&2; exit 1; }
    echo "File $file_name created successfully."
}

main() {
    local dir_name="${1:-.}"
    local file_name="${2:-$(date +"%Y-%m-%d_%H-%M-%S").txt}"
    local answer

    create_directory "$dir_name"

    local full_file_path="$dir_name/$file_name"
    if [[ -e "$full_file_path" ]]; then
        read -rp "File $file_name already exists. Do you want to overwrite it? [y/N]: " answer
        if [[ $answer != "Y" && $answer != "y" ]]; then
            echo "Aborted. File $file_name was not created."
            exit 0
        fi
    fi

    # Get file content from user and create or overwrite the file with it
    echo "Enter the file content (press Ctrl+D to finish):"
    create_file "$full_file_path"
}

main "$@"

