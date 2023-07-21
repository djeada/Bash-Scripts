#!/bin/bash

# Script: generate_pdf.sh
# Description: This script adds a page break between chapters in Markdown files and converts them to PDF using Pandoc.

# Define the output filename
output_file="output.pdf"

# Discover all Markdown files in the current directory
md_files=$(find . -maxdepth 1 -type f -name "*.md" | sort)

# Check if any Markdown file is found
if [ -z "$md_files" ]; then
    echo "No Markdown files found in the current directory."
    exit 1
fi

# Iterate over Markdown files
for file in $md_files; do
    # Check if the page break command exists in the file
    if grep -q '\\newpage' "$file"; then
        echo "Page break already exists in $file"
    else
        # Add the page break command to the file
        awk '/^#/ && !f {print "\\newpage"; f=1} 1' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
        echo "Added page break to $file"
    fi
done

# Convert Markdown files to PDF using Pandoc
pandoc $md_files --from markdown --to pdf --output "$output_file"

echo "PDF generated successfully."
