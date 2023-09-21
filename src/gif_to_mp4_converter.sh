#!/bin/bash

# Script to convert a GIF into a formatted MP4 file.

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

# Convert GIF to MP4
ffmpeg -i "$INPUT_FILE" "$TEMP_FILE1"
if [ $? -ne 0 ]; then
    echo "Error during the GIF to MP4 conversion."
    exit 1
fi

# Scale the video
ffmpeg -i "$TEMP_FILE1" -vf scale=1080:1920 "$TEMP_FILE2"
if [ $? -ne 0 ]; then
    rm "$TEMP_FILE1"
    echo "Error during the scaling process."
    exit 1
fi

# Final formatting
ffmpeg -i "$TEMP_FILE2" -c:v mpeg4 -q:v 5 "$OUTPUT_FILE"
if [ $? -ne 0 ]; then
    rm "$TEMP_FILE1"
    rm "$TEMP_FILE2"
    echo "Error during the final formatting process."
    exit 1
fi

# Cleanup temp files
rm "$TEMP_FILE1"
rm "$TEMP_FILE2"

echo "Conversion completed successfully. Output file: $OUTPUT_FILE"
