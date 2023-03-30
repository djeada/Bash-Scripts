#!/bin/bash

# Check for correct number of arguments
if [ $# -ne 2 ]
then
  echo "Usage: $0 file1 file2"
  exit 1
fi

# Assign arguments to variables
file1="$1"
file2="$2"

# Check if files exist
if [ ! -f "$file1" ] || [ ! -f "$file2" ]
then
  echo "One or both files do not exist."
  exit 1
fi

# Create temporary file
temp=$(mktemp)

# Swap file contents
cp "$file1" "$temp"
cp "$file2" "$file1"
cp "$temp" "$file2"

# Clean up temporary file
rm "$temp"

echo "Contents of $file1 and $file2 have been swapped."
