#!/usr/bin/env bash

# Script Name: extend_video_height.sh
# Description: Extends the height of a video by adding black padding (top and bottom)
#              using ffmpeg. The new height is rounded up to an even number.
# Usage: ./extend_video_height.sh input_video output_video scale_factor
#        scale_factor - number >= 1 (e.g. 1.1 makes the video 10% taller)
# Example: ./extend_video_height.sh input.mp4 output.mp4 1.1

# Check for correct number of arguments
if [[ $# -ne 3 ]]; then
    echo "Usage: $0 input_video output_video scale_factor" >&2
    echo "Example: $0 input.mp4 output.mp4 1.1" >&2
    exit 1
fi

for cmd in ffmpeg ffprobe bc; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: '$cmd' is required but not installed." >&2
        exit 1
    fi
done

# Assign arguments to variables
input_video="$1"
output_video="$2"
scale_factor="$3"

if [[ ! -f "$input_video" ]]; then
    echo "Error: Input file '$input_video' not found." >&2
    exit 1
fi

if ! [[ "$scale_factor" =~ ^[0-9]*\.?[0-9]+$ ]] || (( $(echo "$scale_factor < 1" | bc -l) )); then
    echo "Error: scale_factor must be a number >= 1." >&2
    exit 1
fi

# Read the original height
original_height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$input_video")

if ! [[ "$original_height" =~ ^[0-9]+$ ]]; then
    echo "Error: Could not extract video dimensions." >&2
    exit 1
fi

# Calculate the new height (rounded up to an even number, as most codecs require)
new_height=$(echo "h = $original_height * $scale_factor; scale = 0; h = (h + 1.999999) / 2; h * 2" | bc -l)

# Center the original video vertically
padding=$(( (new_height - original_height) / 2 ))

# Run ffmpeg to add padding
ffmpeg -i "$input_video" -vf "pad=width=iw:height=$new_height:x=0:y=$padding:color=black" "$output_video"

