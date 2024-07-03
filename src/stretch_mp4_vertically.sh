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

# Execute the ffmpeg command
ffmpeg -i "$input_file" -vf "scale=iw:ih*$scale_factor,pad=iw:ih*$scale_factor:(ow-iw)/2:(oh-ih*$scale_factor)/2" "$output_file"

echo "Output file created: $output_file"
