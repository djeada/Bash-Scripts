#!/usr/bin/env bash

# Script Name: pdf_page_extractor.sh
# Description: Extracts a range of pages from a PDF file using pdftk.
#              If end-page is omitted, extraction runs to the last page.
# Usage: ./pdf_page_extractor.sh [-h] [-v] [-o output_file] <pdf-file> <start-page> [end-page]
# Options:
#   -h, --help        Display the help message.
#   -v, --verbose     Enable verbose mode.
#   -o, --output      Specify the output file name.
# Example: ./pdf_page_extractor.sh document.pdf 2 5

usage() {
    echo "Usage: $0 [-h] [-v] [-o output_file] <pdf-file> <start-page> [end-page]"
    echo "  -h, --help        Display this help message."
    echo "  -v, --verbose     Enable verbose mode."
    echo "  -o, --output      Specify output file name."
    echo "  If end-page is omitted, pages are extracted up to the last page."
}

# Translate long options into their short equivalents for getopts
args=()
for arg in "$@"; do
    case $arg in
        --help) args+=("-h") ;;
        --verbose) args+=("-v") ;;
        --output) args+=("-o") ;;
        --output=*) args+=("-o" "${arg#--output=}") ;;
        *) args+=("$arg") ;;
    esac
done
set -- "${args[@]}"

# Parse command-line options
VERBOSE=0
OUTPUT_FILE=""
while getopts ":hvo:" opt; do
    case $opt in
        h)
            usage
            exit 0
            ;;
        v)
            VERBOSE=1
            ;;
        o)
            OUTPUT_FILE=$OPTARG
            ;;
        :)
            echo "Error: Option -$OPTARG requires an argument." >&2
            usage >&2
            exit 1
            ;;
        "?")
            echo "Error: Invalid option: -$OPTARG" >&2
            usage >&2
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

# Check number of arguments
if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo "Error: Wrong number of arguments" >&2
    usage >&2
    exit 1
fi

PDF_FILE="$1"
START_PAGE="$2"
END_PAGE="${3:-}"

# Check for pdftk
if ! command -v pdftk &> /dev/null; then
    echo "Error: pdftk is not installed." >&2
    exit 1
fi

# Check if the PDF file exists
if [[ ! -f "$PDF_FILE" ]]; then
    echo "Error: File not found - $PDF_FILE" >&2
    exit 1
fi

# Find total number of pages
TOTAL_PAGES=$(pdftk "$PDF_FILE" dump_data 2>/dev/null | awk '/^NumberOfPages:/ {print $2}')
if ! [[ "$TOTAL_PAGES" =~ ^[0-9]+$ ]]; then
    echo "Error: Could not read the page count of $PDF_FILE." >&2
    exit 1
fi

# Default the end page to the last page
if [[ -z "$END_PAGE" ]]; then
    END_PAGE="$TOTAL_PAGES"
fi

# Validate page numbers (base 10, so values like 08 are not read as octal)
if ! [[ "$START_PAGE" =~ ^[0-9]+$ ]] || ! [[ "$END_PAGE" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid page range specified." >&2
    exit 1
fi
if (( 10#$START_PAGE < 1 || 10#$START_PAGE > 10#$END_PAGE )); then
    echo "Error: Invalid page range specified." >&2
    exit 1
fi
START_PAGE=$((10#$START_PAGE))
END_PAGE=$((10#$END_PAGE))

# Check if end page is greater than total pages
if (( END_PAGE > TOTAL_PAGES )); then
    echo "Error: End page ($END_PAGE) is greater than total pages ($TOTAL_PAGES)." >&2
    exit 1
fi

# Set default output file name if not specified
if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="${PDF_FILE%.pdf}_pages_${START_PAGE}-${END_PAGE}.pdf"
fi

# Create new PDF with specified pages
if [[ $VERBOSE -eq 1 ]]; then
    echo "Extracting pages $START_PAGE to $END_PAGE from $PDF_FILE..."
fi
if ! pdftk "$PDF_FILE" cat "${START_PAGE}-${END_PAGE}" output "$OUTPUT_FILE"; then
    echo "Error: pdftk failed to extract the pages." >&2
    exit 1
fi

echo "New PDF saved as $OUTPUT_FILE"

