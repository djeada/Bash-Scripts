#!/usr/bin/env bash

# Script Name: convert_to_mp4.sh
# Description: Converts a given video file to MP4 format.
# Usage: ./convert_to_mp4.sh <file_path>
# Example: ./convert_to_mp4.sh video.avi

LOG_FILE="/var/log/convert_to_mp4.log"
LOG_ENABLED=1

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

# Function to process the video file
convert_to_mp4() {
    local file_path=$1
    local basename=$(basename "$file_path")
    local filename="${basename%.*}"
    local output_file="${filename}.mp4"

    log_action "Starting conversion of $file_path to $output_file."
    if ffmpeg -i "$file_path" -vcodec libx264 -acodec aac "$output_file"; then
        echo "Successfully converted $file_path to $output_file"
        log_action "Successfully converted $file_path to $output_file."
    else
        echo "Error: Conversion failed."
        log_action "Error: Conversion failed for $file_path."
        exit 1
    fi
}

main() {
    if [ "$#" -ne 1 ]; then
        usage
        log_action "Error: No file path provided."
        exit 1
    fi

    local file_path=$1

    # Check if the file exists
    if [ ! -f "$file_path" ]; then
        echo "Error: File does not exist."
        log_action "Error: File does not exist at path $file_path."
        exit 1
    fi

    convert_to_mp4 "$file_path"
}

main "$@"
