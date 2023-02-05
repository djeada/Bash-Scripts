#!/bin/bash

# Define target dimensions
width=2480
height=3508

# Get a list of all JPG files in the current directory
files=$(find . -maxdepth 1 -type f -name "*.jpg")

# Check if there are any JPG files in the current directory
if [ -z "$files" ]; then
  echo "No JPG files found in the current directory."
  exit 1
fi

# Resize each JPG file and overwrite the original file
for file in $files; do
  echo "Resizing $file..."
  convert "$file" -resize "${width}x${height}!" "$file"
  if [ $? -ne 0 ]; then
    echo "Error resizing $file. Skipping..."
  fi
done

echo "Resizing complete."
