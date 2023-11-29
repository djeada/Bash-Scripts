#!/bin/bash

# Script: generate_pdf.sh
# Description: Converts Markdown files to PDF with page breaks between chapters

# Constants
OUTPUT_FILE="output.pdf"        # Name of the output PDF file
PAPER_SIZE="a5"                # Paper size (e.g., a5, a4, letter)
BACKUP_DIR_PREFIX="./backup_"  # Prefix for backup directory

# Discover all Markdown files in the current directory
md_files=( $(find . -maxdepth 1 -type f -name "*.md" | sort) )

# Check if any Markdown file is found
if [ -z "${md_files[*]}" ]; then
    echo "No Markdown files found in the current directory."
    exit 1
fi

# Create a backup directory
backup_dir="${BACKUP_DIR_PREFIX}$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

# Iterate over Markdown files
for file in "${md_files[@]}"; do
    # Backup the original file
    cp "$file" "$backup_dir"

    # Add a page break if it does not exist
    if ! grep -q '\\newpage' "$file"; then
        awk '/^#/ && !f {print "\\newpage"; f=1} 1' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
        echo "Added page break to $file"
    fi
done

# Convert Markdown files to PDF using Pandoc
pandoc "${md_files[@]}" --from markdown --to pdf --output "$OUTPUT_FILE" -V papersize=$PAPER_SIZE

echo "PDF generated successfully. Original files have been backed up in $backup_dir."
