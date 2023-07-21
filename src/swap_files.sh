#!/bin/bash

# Script Name: swap_files.sh
# Description: Swaps the contents of two files.
# Usage: swap_files.sh file1 file2
#        file1 - path to the first file
#        file2 - path to the second file
# Example: ./swap_files.sh file1.txt file2.txt

check_arguments() {
    if [ $# -ne 2 ]; then
        echo "Usage: $0 file1 file2"
        exit 1
    fi
}

check_file_existence() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "File $file does not exist."
        exit 1
    fi
}

swap_file_contents() {
    local file1="$1"
    local file2="$2"
    local temp=''
    temp=$(mktemp)

    cp "$file1" "$temp"
    cp "$file2" "$file1"
    cp "$temp" "$file2"

    rm "$temp"
}

main() {
    check_arguments "$@"

    local file1="$1"
    local file2="$2"

    check_file_existence "$file1"
    check_file_existence "$file2"

    swap_file_contents "$file1" "$file2"

    echo "Contents of $file1 and $file2 have been swapped."
}

main "$@"

