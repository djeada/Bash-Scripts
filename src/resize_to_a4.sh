#!/bin/bash

# Script Name: resize_images.sh
# Description: Resize image files in a specified directory to a target dimension with various options.
# Usage: ./resize_images.sh [options]
# Dependencies: Requires ImageMagick's 'convert' command.

# Exit immediately if a command exits with a non-zero status.
set -e

# Default configurations
TARGET_WIDTH=2480
TARGET_HEIGHT=3508
INPUT_DIR="."
OUTPUT_DIR="."
IMAGE_FORMATS=("jpg" "jpeg")
OVERWRITE=false
PRESERVE_ASPECT_RATIO=false
VERBOSE=false
BACKUP=false
LOG_FILE=""
THREADS=1

# Print usage information
usage() {
    echo "Usage: $0 [options]
Options:
  -i, --input-dir DIR       Specify input directory (default: current directory)
  -o, --output-dir DIR      Specify output directory (default: current directory)
  -s, --size WxH            Specify target dimensions (e.g., 2480x3508)
  -f, --formats FORMAT(S)   Specify image formats (comma-separated, e.g., jpg,png)
  -w, --overwrite           Overwrite original files
  -p, --preserve-aspect     Preserve aspect ratio
  -b, --backup              Backup original files before resizing
  -v, --verbose             Enable verbose output
  -l, --log-file FILE       Log output to specified file
  -t, --threads N           Number of concurrent threads (default: 1)
  -h, --help                Display this help message and exit"
}

# Log function
log() {
    if [ "$VERBOSE" = true ]; then
        echo "$1"
    fi
    if [ -n "$LOG_FILE" ]; then
        echo "$1" >> "$LOG_FILE"
    fi
}

# Check for ImageMagick's 'convert' command
if ! command -v convert >/dev/null 2>&1; then
    echo "This script requires ImageMagick's 'convert'. Please install it and rerun the script."
    exit 1
fi

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -i|--input-dir)
            INPUT_DIR="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -s|--size)
            if [[ "$2" =~ ^[0-9]+x[0-9]+$ ]]; then
                IFS='x' read -r TARGET_WIDTH TARGET_HEIGHT <<< "$2"
            else
                echo "Invalid size format. Use WIDTHxHEIGHT (e.g., 2480x3508)."
                exit 1
            fi
            shift 2
            ;;
        -f|--formats)
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
            LOG_FILE="$2"
            shift 2
            ;;
        -t|--threads)
            if [[ "$2" =~ ^[0-9]+$ ]]; then
                THREADS="$2"
            else
                echo "Invalid number of threads. Please specify an integer."
                exit 1
            fi
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate input directory
if [ ! -d "$INPUT_DIR" ]; then
    echo "Input directory '$INPUT_DIR' does not exist."
    exit 1
fi

# Create output directory if it doesn't exist
if [ "$OVERWRITE" = false ] && [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
fi

# Find image files
FILES=()
for format in "${IMAGE_FORMATS[@]}"; do
    while IFS= read -r -d $'\0' file; do
        FILES+=("$file")
    done < <(find "$INPUT_DIR" -type f \( -iname "*.${format}" -o -iname "*.${format^^}" \) -print0)
done

# Check if there are any image files
if [ ${#FILES[@]} -eq 0 ]; then
    echo "No image files found in '$INPUT_DIR' with formats: ${IMAGE_FORMATS[*]}."
    exit 1
fi

# Function to resize images
resize_image() {
    local file="$1"
    local output_file="$2"
    local options=()
    
    if [ "$PRESERVE_ASPECT_RATIO" = true ]; then
        options+=("-resize" "${TARGET_WIDTH}x${TARGET_HEIGHT}")
    else
        options+=("-resize" "${TARGET_WIDTH}x${TARGET_HEIGHT}!")
    fi
    
    log "Processing '$file'..."
    
    if [ "$BACKUP" = true ] && [ "$OVERWRITE" = true ]; then
        cp "$file" "${file}.bak"
        log "Backup created for '$file'."
    fi

    if ! convert "$file" "${options[@]}" "$output_file"; then
        log "Error resizing '$file'."
        return 1
    fi
    log "Successfully resized '$file' -> '$output_file'."
}

# Export variables and functions for GNU Parallel
export TARGET_WIDTH TARGET_HEIGHT PRESERVE_ASPECT_RATIO BACKUP OVERWRITE LOG_FILE VERBOSE
export -f resize_image log

# Check for GNU Parallel if threads > 1
if [ "$THREADS" -gt 1 ]; then
    if ! command -v parallel >/dev/null 2>&1; then
        echo "GNU Parallel is not installed. Please install it or set threads to 1."
        exit 1
    fi
fi

# Process images
if [ "$THREADS" -gt 1 ]; then
    parallel -j "$THREADS" --bar resize_image "{}" "$(
        if [ "$OVERWRITE" = true ]; then
            echo "{}"
        else
            echo "$OUTPUT_DIR/{/}"
        fi
    )" ::: "${FILES[@]}"
else
    for file in "${FILES[@]}"; do
        filename=$(basename "$file")
        if [ "$OVERWRITE" = true ]; then
            output_file="$file"
        else
            output_file="$OUTPUT_DIR/$filename"
        fi
        resize_image "$file" "$output_file"
    done
fi

echo "Image resizing complete."
