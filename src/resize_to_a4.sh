#!/usr/bin/env bash

# Script Name: resize_to_a4.sh
# Description: Resize image files in a specified directory to a target dimension
#              (A4 at 300 DPI, 2480x3508, by default) with various options.
#              Resized copies go to ./resized unless --overwrite is given.
# Usage: ./resize_to_a4.sh [options]
#        Run with --help for the list of options.
# Dependencies: Requires ImageMagick ('magick' or 'convert'); GNU Parallel for --threads > 1.

set -euo pipefail
IFS=$'\n\t'

# Default configurations
TARGET_WIDTH=2480
TARGET_HEIGHT=3508
INPUT_DIR="."
OUTPUT_DIR="./resized"
IMAGE_FORMATS=("jpg" "jpeg")
OVERWRITE=false
PRESERVE_ASPECT_RATIO=false
VERBOSE=false
BACKUP=false
LOG_FILE=""
THREADS=1

# Print usage information
usage() {
    cat <<EOF
Usage: $0 [options]
Options:
  -i, --input-dir DIR       Specify input directory (default: current directory; not recursive)
  -o, --output-dir DIR      Specify output directory (default: ./resized)
  -s, --size WxH            Specify target dimensions (default: 2480x3508, A4 at 300 DPI)
  -f, --formats FORMAT(S)   Specify image formats (comma-separated, default: jpg,jpeg)
  -w, --overwrite           Overwrite original files instead of writing to the output directory
  -p, --preserve-aspect     Preserve aspect ratio
  -b, --backup              Backup original files (FILE.bak) before overwriting (with -w)
  -v, --verbose             Enable verbose output
  -l, --log-file FILE       Log output to specified file
  -t, --threads N           Number of concurrent jobs (default: 1; N > 1 needs GNU Parallel)
  -h, --help                Display this help message and exit
EOF
}

die() {
    echo "Error: $*" >&2
    exit 1
}

# Log function
log() {
    local msg="$1"
    if [ "$VERBOSE" = true ]; then
        echo "$msg"
    fi
    if [ -n "$LOG_FILE" ]; then
        echo "$msg" >> "$LOG_FILE"
    fi
}

# Ensure an option received a value.
require_value() {
    [[ -n "${2:-}" ]] || die "Option $1 requires a value."
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -i|--input-dir)
            require_value "$1" "${2:-}"
            INPUT_DIR="$2"
            shift 2
            ;;
        -o|--output-dir)
            require_value "$1" "${2:-}"
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -s|--size)
            require_value "$1" "${2:-}"
            if [[ "$2" =~ ^[0-9]+x[0-9]+$ ]]; then
                IFS='x' read -r TARGET_WIDTH TARGET_HEIGHT <<< "$2"
            else
                die "Invalid size format. Use WIDTHxHEIGHT (e.g., 2480x3508)."
            fi
            shift 2
            ;;
        -f|--formats)
            require_value "$1" "${2:-}"
            IFS=',' read -r -a IMAGE_FORMATS <<< "$2"
            shift 2
            ;;
        -w|--overwrite)
            OVERWRITE=true
            shift
            ;;
        -p|--preserve-aspect)
            PRESERVE_ASPECT_RATIO=true
            shift
            ;;
        -b|--backup)
            BACKUP=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -l|--log-file)
            require_value "$1" "${2:-}"
            LOG_FILE="$2"
            shift 2
            ;;
        -t|--threads)
            require_value "$1" "${2:-}"
            if [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
                THREADS="$2"
            else
                die "Invalid number of threads. Please specify a positive integer."
            fi
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# Check for ImageMagick (v7 'magick', or v6 'convert')
if command -v magick >/dev/null 2>&1; then
    IM_CMD=magick
elif command -v convert >/dev/null 2>&1; then
    IM_CMD=convert
else
    die "This script requires ImageMagick ('magick' or 'convert'). Please install it and rerun the script."
fi

# Check for GNU Parallel if threads > 1
if [ "$THREADS" -gt 1 ] && ! command -v parallel >/dev/null 2>&1; then
    die "GNU Parallel is not installed. Please install it or set threads to 1."
fi

# Validate input directory
if [ ! -d "$INPUT_DIR" ]; then
    die "Input directory '$INPUT_DIR' does not exist."
fi

# Create output directory if needed, and refuse to silently overwrite originals
if [ "$OVERWRITE" = false ]; then
    mkdir -p -- "$OUTPUT_DIR"
    if [ "$(cd -- "$INPUT_DIR" && pwd -P)" = "$(cd -- "$OUTPUT_DIR" && pwd -P)" ]; then
        die "Output directory is the input directory; use --overwrite to replace the originals."
    fi
fi

# Find image files (top level of INPUT_DIR only; -iname is case-insensitive)
FILES=()
for format in "${IMAGE_FORMATS[@]}"; do
    while IFS= read -r -d '' file; do
        FILES+=("$file")
    done < <(find "$INPUT_DIR" -maxdepth 1 -type f -iname "*.${format}" -print0)
done

# Check if there are any image files
if [ "${#FILES[@]}" -eq 0 ]; then
    die "No image files found in '$INPUT_DIR' with formats: $(IFS=','; echo "${IMAGE_FORMATS[*]}")."
fi

# Function to resize images
resize_image() {
    local file="$1"
    local output_file="$2"
    local geometry="${TARGET_WIDTH}x${TARGET_HEIGHT}"

    if [ "$PRESERVE_ASPECT_RATIO" = false ]; then
        geometry+="!"
    fi

    log "Processing '$file'..."

    if [ "$BACKUP" = true ] && [ "$OVERWRITE" = true ]; then
        if ! cp -- "$file" "${file}.bak"; then
            echo "Error: could not back up '$file'; skipping it." >&2
            return 1
        fi
        log "Backup created for '$file'."
    fi

    if ! "$IM_CMD" "$file" -resize "$geometry" "$output_file"; then
        echo "Error resizing '$file'." >&2
        if [ -n "$LOG_FILE" ]; then
            echo "Error resizing '$file'." >> "$LOG_FILE"
        fi
        return 1
    fi
    log "Successfully resized '$file' -> '$output_file'."
}

# Print "input<TAB>output" for a file
output_path_for() {
    if [ "$OVERWRITE" = true ]; then
        printf '%s\t%s\n' "$1" "$1"
    else
        printf '%s\t%s\n' "$1" "$OUTPUT_DIR/$(basename -- "$1")"
    fi
}

# Process images
failures=0
if [ "$THREADS" -gt 1 ]; then
    # Export variables and functions for GNU Parallel
    export TARGET_WIDTH TARGET_HEIGHT PRESERVE_ASPECT_RATIO BACKUP OVERWRITE LOG_FILE VERBOSE IM_CMD
    export -f resize_image log
    for file in "${FILES[@]}"; do
        output_path_for "$file"
    done | parallel -j "$THREADS" --bar --colsep '\t' resize_image || failures=$?
else
    for file in "${FILES[@]}"; do
        output_file="$file"
        if [ "$OVERWRITE" = false ]; then
            output_file="$OUTPUT_DIR/$(basename -- "$file")"
        fi
        resize_image "$file" "$output_file" || failures=$((failures + 1))
    done
fi

if [ "$failures" -ne 0 ]; then
    echo "Image resizing finished with $failures failure(s)." >&2
    exit 1
fi
echo "Image resizing complete."

