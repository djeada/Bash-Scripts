#!/usr/bin/env bash

# Script Name: recently_modified_files.sh
# Description: This script lists the most recently modified files in a given directory.
# Usage: recently_modified_files.sh [dir] [n]
#    dir: Directory to search. Defaults to the current directory if not specified.
#    n: Number of files to list. Defaults to 10 if not specified.
# Example: recently_modified_files.sh /home/user/documents 5 - lists the 5 most recently modified files in /home/user/documents

# Function to display usage information
usage() {
    echo "Usage: $0 [dir] [n]"
    echo "  dir: Directory to search. Defaults to the current directory if not specified."
    echo "  n: Number of files to list. Defaults to 10 if not specified."
}

# Parse and assign command line arguments
dir="${1:-.}"
n="${2:-10}"

# Validate directory
if [ ! -d "$dir" ]; then
    echo "Error: Directory '$dir' does not exist."
    usage
    exit 1
fi

# Validate the number of files to list
if ! [[ "$n" =~ ^[0-9]+$ ]]; then
    echo "Error: The number of files to list must be a positive integer."
    usage
    exit 1
fi

# Main logic to find and list files
echo "Most recently modified files in '$dir':"
find "$dir" -type f -printf '%TY-%Tm-%Td %TT %p\n' | sort -r | head -n "$n"
