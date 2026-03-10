#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 input_file scale_factor"
    exit 1
fi

# Assign arguments to variables
input_file=$1
scale_factor=$2

# Extract the filename without extension
filename=$(basename "$input_file")
extension="${filename##*.}"
filename="${filename%.*}"

# Create the output file name
output_file="${filename}_${scale_factor}x.${extension}"

# Get the original dimensions of the input file
original_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$input_file")
original_height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$input_file")

# Calculate the new scaled height
new_height=$(echo "$original_height * $scale_factor" | bc)

# Calculate the total padding (new height minus original height)
total_padding=$(echo "$new_height - $original_height" | bc)

# Calculate padding for top and bottom (equally distributed)
padding_top_bottom=$(echo "$total_padding / 2" | bc)

# Execute the ffmpeg command with proper top and bottom padding
ffmpeg -i "$input_file" -vf "scale=$original_width:$new_height,pad=$original_width:$new_height+$total_padding:0:$padding_top_bottom" "$output_file"

echo "Output file created: $output_file"

