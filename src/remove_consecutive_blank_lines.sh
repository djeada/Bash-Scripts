#!/bin/bash

# Check for correct number of arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

dir="$1"

# Check if the provided path is a directory
if [ ! -d "$dir" ]; then
    echo "Error: '$dir' is not a directory."
    exit 1
fi

# Iterate through all files in the directory
find "$dir" -type f -print0 | while IFS= read -r -d $'\0' file; do
    # Remove consecutive blank lines
    awk 'BEGIN {RS="\n"; ORS="\n"; last_line=""} {if (NF == 0 && last_line == "") {next} else {print; last_line=$0}}' "$file" > "${file}.tmp"
    # Replace the original file with the processed one
    mv "${file}.tmp" "$file"
done

echo "Done. Repeated blank lines have been removed from files in the directory."
