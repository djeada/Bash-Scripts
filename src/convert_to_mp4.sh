#!/bin/bash

# Check if an argument was provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <file_path>"
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
ffmpeg -i "$FILE_PATH" -vcodec libx264 -acodec aac "$OUTPUT_FILE"

echo "Converted $FILE_PATH to $OUTPUT_FILE"
