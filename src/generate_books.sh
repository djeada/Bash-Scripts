#!/usr/bin/env bash

# Script Name: generate_books.sh
# Description: Converts the Markdown files in the current directory (in name order)
#              to a single PDF, treating each file as a chapter and headers as subchapters.
#              A page break is inserted before each chapter's first header, unless the
#              file already contains \newpage. The source files are not modified.
# Usage: ./generate_books.sh
# Dependencies: pandoc (plus a LaTeX engine such as pdflatex for PDF output).

# Constants
OUTPUT_FILE="output.pdf"
PAPER_SIZE="a5"
MARGIN="top=2cm, right=1.5cm, bottom=2cm, left=1.5cm, footskip=8mm"
CONCATENATED_MD=""

# Function to add page breaks and concatenate Markdown files
concatenate_md_files() {
    local file
    for file in "$@"; do
        if grep -q '\\newpage' "$file"; then
            cat "$file"
        else
            awk '/^#/ && !f {print "\\newpage\n"; f=1} 1' "$file"
        fi || { echo "Failed to concatenate file $file." >&2; return 1; }
        # Separate chapters, even if a file lacks a trailing newline.
        printf '\n\n'
    done > "$CONCATENATED_MD"
}

# Function to convert Markdown to PDF
convert_to_pdf() {
    pandoc "$CONCATENATED_MD" --from markdown --to pdf \
        --output "$OUTPUT_FILE" -V papersize="$PAPER_SIZE" -V geometry="$MARGIN" || { echo "Failed to convert to PDF." >&2; exit 1; }
}

# Cleanup function
cleanup() {
    if [ -n "$CONCATENATED_MD" ]; then
        rm -f -- "$CONCATENATED_MD"
    fi
}

# Main logic
if ! command -v pandoc >/dev/null 2>&1; then
    echo "This script requires 'pandoc'. Please install it and rerun the script." >&2
    exit 1
fi

mapfile -t md_files < <(find . -maxdepth 1 -type f -name "*.md" | sort)

if [ ${#md_files[@]} -eq 0 ]; then
    echo "No Markdown files found in the current directory." >&2
    exit 1
fi

# Temporary file lives in the current directory so relative image paths still resolve.
trap cleanup EXIT
CONCATENATED_MD=$(mktemp ./.generate_books.XXXXXX) || { echo "Failed to create a temporary file." >&2; exit 1; }

concatenate_md_files "${md_files[@]}" || exit 1
convert_to_pdf

echo "PDF generated successfully: $OUTPUT_FILE"

