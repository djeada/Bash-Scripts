#!/usr/bin/env bash

# Script Name: stretch_mp4_vertically.sh
# Description: Stretches an MP4 video vertically by a given scale factor using ffmpeg.
#              The frame is scaled to height*factor and then padded (black bars, centered)
#              by the same amount again. The output is written to the current directory
#              as <name>_<factor>x.<ext>.
# Usage: ./stretch_mp4_vertically.sh input_file scale_factor
#        scale_factor - a number >= 1 (e.g. 1.5)
# Example: ./stretch_mp4_vertically.sh video.mp4 1.5

set -euo pipefail

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 input_file scale_factor" >&2
    exit 1
fi

for cmd in ffmpeg ffprobe; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd is required but not installed." >&2
        exit 1
    fi
done

# Assign arguments to variables
input_file=$1
scale_factor=$2

if [ ! -f "$input_file" ]; then
    echo "Error: '$input_file' is not a file." >&2
    exit 1
fi

if ! [[ $scale_factor =~ ^[0-9]+(\.[0-9]+)?$ ]] || ! awk -v f="$scale_factor" 'BEGIN { exit !(f >= 1) }'; then
    echo "Error: scale_factor must be a number >= 1." >&2
    exit 1
fi

# Extract the filename without extension
filename=$(basename "$input_file")
extension="${filename##*.}"
filename="${filename%.*}"

# Create the output file name
output_file="${filename}_${scale_factor}x.${extension}"

# Get the original dimensions of the input file
original_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$input_file")
original_height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$input_file")

if ! [[ $original_width =~ ^[0-9]+$ && $original_height =~ ^[0-9]+$ ]]; then
    echo "Error: could not read video dimensions from '$input_file'." >&2
    exit 1
fi

# Calculate the new scaled height, rounded to an even integer (required by most encoders)
new_height=$(awk -v h="$original_height" -v f="$scale_factor" 'BEGIN { printf "%d", int(h * f / 2 + 0.5) * 2 }')

# Calculate the total padding (new height minus original height) and the top offset
total_padding=$((new_height - original_height))
padding_top=$((total_padding / 2))

# Execute the ffmpeg command with proper top and bottom padding
ffmpeg -i "$input_file" -vf "scale=$original_width:$new_height,pad=$original_width:$((new_height + total_padding)):0:$padding_top" "$output_file"

echo "Output file created: $output_file"

