#!/bin/bash

# Script: generate_pdf.sh
# Description: Converts Markdown files to PDF, treating each file as a chapter and headers as subchapters.

# Constants
OUTPUT_FILE="output.pdf"
PAPER_SIZE="a5"
BACKUP_DIR_PREFIX="./backup_"
MARGIN="top=2cm, right=1.5cm, bottom=2cm, left=1.5cm, footskip=8mm"
CONCATENATED_MD="concatenated.md"

# Function to create a backup of files
backup_files() {
    local backup_dir="${BACKUP_DIR_PREFIX}$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir" || { echo "Failed to create backup directory."; exit 1; }
    for file in "$@"; do
        cp "$file" "$backup_dir" || { echo "Failed to copy file $file to backup."; continue; }
    done
    echo "$backup_dir"
}

# Function to add page breaks and concatenate Markdown files
concatenate_md_files() {
    local files=("$@")
    : > "$CONCATENATED_MD" # Safely truncate file
    for file in "${files[@]}"; do
        if ! grep -q '\\newpage' "$file"; then
            awk '/^#/ && !f {print "\\newpage\n"; f=1} 1' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
        fi
        cat "$file" >> "$CONCATENATED_MD" || { echo "Failed to concatenate file $file."; continue; }
    done
}

# Function to convert Markdown to PDF
convert_to_pdf() {
    pandoc "$CONCATENATED_MD" --from markdown --to pdf \
        --output "$OUTPUT_FILE" -V papersize="$PAPER_SIZE" -V geometry="$MARGIN" || { echo "Failed to convert to PDF."; exit 1; }
}

# Cleanup function
cleanup() {
    echo "Cleaning up temporary files..."
    [ -f "$CONCATENATED_MD" ] && rm "$CONCATENATED_MD"
}

# Main logic
trap cleanup EXIT

md_files=( $(find . -maxdepth 1 -type f -name "*.md" | sort) )

if [ ${#md_files[@]} -eq 0 ]; then
    echo "No Markdown files found in the current directory."
    exit 1
fi

backup_dir=$(backup_files "${md_files[@]}")
concatenate_md_files "${md_files[@]}"
convert_to_pdf

if [ -f "$OUTPUT_FILE" ]; then
    echo "PDF generated successfully. Original files have been backed up in $backup_dir."
else
    echo "PDF generation failed."
fi
