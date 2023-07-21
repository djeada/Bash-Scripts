#!/bin/bash

# Script Name: resize_to_a4.sh
# Description: Resize all JPG files in the current directory to a specified dimension.
# Usage: ./resize_to_a4.sh
# Dependencies: Requires ImageMagick's 'convert' command.

# Target dimensions
readonly TARGET_WIDTH=2480
readonly TARGET_HEIGHT=3508

# Find all JPG files in the current directory, up to one level deep
readonly FILES=''
FILES=$(find . -maxdepth 1 -type f -iname "*.jpg")

# Check for ImageMagick's 'convert' command
if ! command -v convert >/dev/null 2>&1; then
    echo "This script requires ImageMagick's 'convert'. Please install it and rerun the script."
    exit 1
fi

# Check if there are any JPG files in the current directory
if [[ -z "${FILES}" ]]; then
    echo "No JPG files found in the current directory."
    exit 1
fi

# Function to resize images
resize_image() {
    local file=$1
    echo "Resizing ${file}..."
    if ! "$(convert "${file}" -resize "${TARGET_WIDTH}x${TARGET_HEIGHT}!" "${file}")"; then
        echo "Error resizing ${file}. Skipping..."
    fi
}

# Resize each JPG file and overwrite the original file
for file in ${FILES}; do
    resize_image "${file}"
done

echo "Resizing complete."

