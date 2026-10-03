#!/usr/bin/env bash

# Script Name: convert_to_gif.sh
# Description: Converts a given video file to a GIF, written to the current directory
#              as <input name>.gif. Frames larger than 200 megapixels are scaled down.
#              Actions are logged to /var/log/convert_to_gif.log when it is writable.
# Usage: ./convert_to_gif.sh <file_path>
# Example: ./convert_to_gif.sh video.mp4

LOG_FILE="/var/log/convert_to_gif.log"
LOG_ENABLED=1

# Function to log actions (silently skipped if the log file isn't writable)
log_action() {
    if [ "$LOG_ENABLED" -eq 1 ]; then
        { echo "$(date +"%Y-%m-%d %T"): $1" >> "$LOG_FILE"; } 2>/dev/null || true
    fi
}

# Print an error to stderr and log it
error() {
    echo "Error: $1" >&2
    log_action "Error: $1"
}

# Usage function
usage() {
    echo "Usage: $0 <file_path>" >&2
}

# Check for required dependencies
if ! command -v ffmpeg &> /dev/null; then
    error "ffmpeg is not installed. Please install it and try again."
    exit 1
fi

# Check if an argument was provided
if [ "$#" -ne 1 ]; then
    usage
    exit 1
fi

FILE_PATH=$1

# Check if the file exists
if [ ! -f "$FILE_PATH" ]; then
    error "File does not exist: $FILE_PATH"
    exit 1
fi

# Get the file name without extension
BASENAME=$(basename -- "$FILE_PATH")
FILENAME="${BASENAME%.*}"

# Set the output file name
OUTPUT_FILE="${FILENAME}.gif"

# Maximum dimension for 200 megapixels: floor(sqrt(200 * 1000000))
MAX_DIMENSION=14142

# Convert the file with resize if necessary
log_action "Starting conversion of $FILE_PATH to $OUTPUT_FILE."
if ffmpeg -i "$FILE_PATH" -vf "scale='min(iw,$MAX_DIMENSION)':'min(ih,$MAX_DIMENSION)':force_original_aspect_ratio=decrease" -f gif "$OUTPUT_FILE"; then
    echo "Successfully converted $FILE_PATH to $OUTPUT_FILE"
    log_action "Successfully converted $FILE_PATH to $OUTPUT_FILE."
else
    error "Conversion failed for $FILE_PATH."
    exit 1
fi

