#!/usr/bin/env bash

# Script Name: recently_modified_files.sh
# Description: This script lists the most recently modified files in a given directory.
# Usage: `recently_modified_files.sh [dir] [n]`
# Example: `recently_modified_files.sh /home/user/documents 5` lists the 5 most recently modified files in the directory `/home/user/documents`

dir="$1"
n="$2"

# Set default values for dir and n if no arguments are provided
if [ -z "$dir" ]; then
    dir="."
fi

if [ -z "$n" ]; then
    n=10
fi

find "$dir" -type f -printf '%TY-%Tm-%Td %TT %p\n' | sort -r | head -n "$n"
