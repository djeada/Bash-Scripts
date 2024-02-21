#!/bin/bash

# Script Name: speed_up_video.sh
# Description: This script speeds up a video file by a specified multiplier using ffmpeg.
#              It checks for the correct number of arguments, processes the video, and saves the output.
# Usage: speed_up_video.sh <path_to_video> <speed_multiplier>
#        <path_to_video> - Full path to the video file to be processed.
#        <speed_multiplier> - Numeric value indicating how much faster the video should be.
# Example: ./speed_up_video.sh /path/to/video.mp4 2.0

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <path_to_video> <speed_multiplier>"
    exit 1
fi

VIDEO_PATH=$1
SPEED=$2

FILENAME=$(basename -- "$VIDEO_PATH")
EXTENSION="${FILENAME##*.}"
FILENAME="${FILENAME%.*}"

OUTPUT="${FILENAME}_x${SPEED}.${EXTENSION}"

# Speeding up the video using ffmpeg
ffmpeg -i "$VIDEO_PATH" -filter:v "setpts=PTS/${SPEED}" -an "$OUTPUT"

echo "Output saved as $OUTPUT"
