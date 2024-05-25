#!/bin/bash

# Check for correct number of arguments
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 input_video output_video scale_factor"
  echo "Example: $0 input.mp4 output.mp4 1.1"
  exit 1
fi

# Assign arguments to variables
input_video=$1
output_video=$2
scale_factor=$3

# Calculate the new height
eval "$(ffprobe -v error -of flat=s=_ -select_streams v:0 -show_entries stream=height,width $input_video)"
original_height=${streams_stream_0_height}
original_width=${streams_stream_0_width}
new_height=$(echo "$original_height * $scale_factor" | bc)

# Calculate the padding needed
padding=$(echo "($new_height - $original_height) / 2" | bc)

# Run ffmpeg to add padding
ffmpeg -i "$input_video" -vf "pad=width=iw:height=$new_height:x=0:y=$padding:color=black" "$output_video"
