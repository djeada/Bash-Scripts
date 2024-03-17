#!/bin/bash

# Function to check if a command exists
command_exists() {
    type "$1" &> /dev/null
}

# Check for required dependencies
if ! command_exists ffmpeg; then
    echo "Error: ffmpeg is not installed. Please install it and try again."
    exit 1
fi

# Usage function
usage() {
    echo "Usage: $0 <file_path>"
}

# Check if an argument was provided
if [ "$#" -ne 1 ]; then
    usage
    exit 1
fi

FILE_PATH=$1

# Check if the file exists
if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File does not exist."
    exit 1
fi

# Get the file name without extension
BASENAME=$(basename "$FILE_PATH")
FILENAME="${BASENAME%.*}"

# Set the output file name
OUTPUT_FILE="${FILENAME}.gif"

# Maximum dimension for 200 megapixels
MAX_DIMENSION=$(echo "sqrt(200*1000000)" | bc)

# Convert the file with resize if necessary
if ffmpeg -i "$FILE_PATH" -vf "scale='min(iw,$MAX_DIMENSION)':'min(ih,$MAX_DIMENSION)':force_original_aspect_ratio=decrease" -f gif "$OUTPUT_FILE"; then
    echo "Successfully converted $FILE_PATH to $OUTPUT_FILE"
else
    echo "Error: Conversion failed."
    exit 1
fi
