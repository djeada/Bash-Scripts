#!/usr/bin/env bash

# Script Name: convert_to_gif.sh
# Description: Converts a given video file to a GIF.
# Usage: ./convert_to_gif.sh <file_path>
# Example: ./convert_to_gif.sh video.mp4

LOG_FILE="/var/log/convert_to_gif.log"
LOG_ENABLED=1

# Function to log actions
log_action() {
    [ $LOG_ENABLED -eq 1 ] && echo "$(date +"%Y-%m-%d %T"): $1" >> $LOG_FILE
}

# Function to check if a command exists
command_exists() {
    type "$1" &> /dev/null
}

# Check for required dependencies
if ! command_exists ffmpeg; then
    echo "Error: ffmpeg is not installed. Please install it and try again."
    log_action "Error: ffmpeg is not installed."
    exit 1
fi

# Usage function
usage() {
    echo "Usage: $0 <file_path>"
    log_action "Displayed usage information."
}

# Check if an argument was provided
if [ "$#" -ne 1 ]; then
    usage
    log_action "Error: No file path provided."
    exit 1
fi

FILE_PATH=$1

# Check if the file exists
if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File does not exist."
    log_action "Error: File does not exist at path $FILE_PATH."
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
log_action "Starting conversion of $FILE_PATH to $OUTPUT_FILE."
if ffmpeg -i "$FILE_PATH" -vf "scale='min(iw,$MAX_DIMENSION)':'min(ih,$MAX_DIMENSION)':force_original_aspect_ratio=decrease" -f gif "$OUTPUT_FILE"; then
    echo "Successfully converted $FILE_PATH to $OUTPUT_FILE"
    log_action "Successfully converted $FILE_PATH to $OUTPUT_FILE."
else
    echo "Error: Conversion failed."
    log_action "Error: Conversion failed for $FILE_PATH."
    exit 1
fi
