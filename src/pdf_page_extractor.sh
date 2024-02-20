#!/bin/bash

usage() {
    echo "Usage: $0 [-h] [-v] [-o output_file] <pdf-file> <start-page> [end-page]"
    echo "  -h, --help        Display this help message."
    echo "  -v, --verbose     Enable verbose mode."
    echo "  -o, --output      Specify output file name."
}

# Parse command-line options
VERBOSE=0
OUTPUT_FILE=""
while getopts "hvo:" opt; do
    case $opt in
        h) usage; exit 0;;
        v) VERBOSE=1;;
        o) OUTPUT_FILE=$OPTARG;;
        \?) echo "Invalid option: -$OPTARG" >&2; exit 1;;
    esac
done

shift $((OPTIND-1))

# Check minimum number of arguments
if [ "$#" -lt 2 ]; then
    echo "Error: Too few arguments"
    usage
    exit 1
fi

PDF_FILE=$1
START_PAGE=$2
END_PAGE=${3:- -1}

# Check for pdftk
if ! command -v pdftk &> /dev/null; then
    echo "Error: pdftk is not installed."
    exit 1
fi

# Check if the PDF file exists
if [ ! -f "$PDF_FILE" ]; then
    echo "Error: File not found - $PDF_FILE"
    exit 1
fi

# Find total number of pages
TOTAL_PAGES=$(pdftk "$PDF_FILE" dump_data | grep NumberOfPages | awk '{print $2}')

# Validate page numbers
if ! [[ $START_PAGE =~ ^[0-9]+$ ]] || ! [[ $END_PAGE =~ ^[0-9]+$ ]] || [ "$START_PAGE" -gt "$END_PAGE" ]; then
    echo "Error: Invalid page range specified."
    exit 1
fi

# Replace -1 with the total number of pages
if [ "$END_PAGE" -eq -1 ]; then
    END_PAGE=$TOTAL_PAGES
fi

# Check if end page is greater than total pages
if [ "$END_PAGE" -gt "$TOTAL_PAGES" ]; then
    echo "Error: End page ($END_PAGE) is greater than total pages ($TOTAL_PAGES)."
    exit 1
fi

# Set default output file name if not specified
if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="${PDF_FILE%.pdf}_pages_$START_PAGE-$END_PAGE.pdf"
fi

# Create new PDF with specified pages
if [ $VERBOSE -eq 1 ]; then
    echo "Extracting pages $START_PAGE to $END_PAGE from $PDF_FILE..."
fi
pdftk "$PDF_FILE" cat $START_PAGE-$END_PAGE output "$OUTPUT_FILE"

echo "New PDF saved as $OUTPUT_FILE"
