#!/bin/bash

# Script to convert a GIF into a formatted MP4 file.

# Function to check for command errors
check_error() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        cleanup
        exit 1
    fi
}

# Function for cleanup
cleanup() {
    echo "Cleaning up temporary files..."
    rm -f "$TEMP_FILE1" "$TEMP_FILE2"
}

# Check if the correct number of arguments is given
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 [input_gif_file]"
    exit 1
fi

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed."
    exit 1
fi

# Variables
INPUT_FILE="$1"
DATE_STRING=$(date +"%Y%m%d%H%M%S")
TEMP_FILE1="temp_output1_${DATE_STRING}.mp4"
TEMP_FILE2="temp_output2_${DATE_STRING}.mp4"
OUTPUT_FILE="formatted_output_${DATE_STRING}.mp4"

trap cleanup EXIT

# Convert GIF to MP4
echo "Converting GIF to MP4..."
ffmpeg -i "$INPUT_FILE" "$TEMP_FILE1"
check_error "during the GIF to MP4 conversion."

# Scale the video
echo "Scaling the video..."
ffmpeg -i "$TEMP_FILE1" -vf scale=1080:1920 "$TEMP_FILE2"
check_error "during the scaling process."

# Final formatting
echo "Applying final formatting..."
ffmpeg -i "$TEMP_FILE2" -c:v mpeg4 -q:v 5 "$OUTPUT_FILE"
check_error "during the final formatting process."

echo "Conversion completed successfully. Output file: $OUTPUT_FILE"
