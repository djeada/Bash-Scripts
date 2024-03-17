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
OUTPUT_FILE="${FILENAME}.mp4"

# Convert the file
if ffmpeg -i "$FILE_PATH" -vcodec libx264 -acodec aac "$OUTPUT_FILE"; then
    echo "Successfully converted $FILE_PATH to $OUTPUT_FILE"
else
    echo "Error: Conversion failed."
    exit 1
fi
