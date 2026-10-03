#!/usr/bin/env bash

# Script Name: speed_up_video.sh
# Description: This script speeds up a video file by a specified multiplier using ffmpeg.
#              The audio track is dropped. The output is written to the current directory
#              as <name>_x<speed_multiplier>.<extension>.
# Usage: speed_up_video.sh <path_to_video> <speed_multiplier>
#        <path_to_video> - Full path to the video file to be processed.
#        <speed_multiplier> - Positive number indicating how much faster the video should be.
# Example: ./speed_up_video.sh /path/to/video.mp4 2.0

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <path_to_video> <speed_multiplier>" >&2
    exit 1
fi

VIDEO_PATH=$1
SPEED=$2

if [ ! -f "$VIDEO_PATH" ]; then
    echo "Error: '$VIDEO_PATH' is not a file." >&2
    exit 1
fi

if ! [[ "$SPEED" =~ ^([0-9]+\.?[0-9]*|\.[0-9]+)$ ]] || ! awk -v s="$SPEED" 'BEGIN { exit !(s > 0) }'; then
    echo "Error: speed multiplier must be a positive number." >&2
    exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Error: this script requires 'ffmpeg'." >&2
    exit 1
fi

FILENAME=$(basename -- "$VIDEO_PATH")
if [[ "$FILENAME" == ?*.* ]]; then
    EXTENSION=".${FILENAME##*.}"
    FILENAME="${FILENAME%.*}"
else
    EXTENSION=""
fi

OUTPUT="${FILENAME}_x${SPEED}${EXTENSION}"

# Speeding up the video using ffmpeg
if ! ffmpeg -i "$VIDEO_PATH" -filter:v "setpts=PTS/${SPEED}" -an "$OUTPUT"; then
    echo "Error: ffmpeg failed to process '$VIDEO_PATH'." >&2
    exit 1
fi

echo "Output saved as $OUTPUT"

