#!/usr/bin/env bash

# Script Name: gif_to_mp4_converter.sh
# Description: Converts a GIF file into a 1080x1920 MP4 file (MPEG-4 video) using ffmpeg.
#              The output is written to the current directory as
#              formatted_output_<timestamp>.mp4.
# Usage: ./gif_to_mp4_converter.sh input_gif_file
# Example: ./gif_to_mp4_converter.sh animation.gif

# Check if the correct number of arguments is given
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 input_gif_file" >&2
    exit 1
fi

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed." >&2
    exit 1
fi

# Variables
INPUT_FILE="$1"
OUTPUT_FILE="formatted_output_$(date +"%Y%m%d%H%M%S").mp4"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found." >&2
    exit 1
fi

# Convert, scale and encode in a single pass (no lossy intermediate files)
echo "Converting GIF to MP4..."
if ! ffmpeg -n -i "$INPUT_FILE" -vf scale=1080:1920 -c:v mpeg4 -q:v 5 "$OUTPUT_FILE"; then
    echo "Error: ffmpeg failed to convert '$INPUT_FILE'." >&2
    rm -f "$OUTPUT_FILE"
    exit 1
fi

echo "Conversion completed successfully. Output file: $OUTPUT_FILE"

