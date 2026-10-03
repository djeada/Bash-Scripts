#!/usr/bin/env bash

# Script Name: are_anagrams.sh
# Description: Checks if two or more strings are anagrams of each other.
#              Supports various options to customize comparison behavior.
# Usage: ./are_anagrams.sh [options] [string1 string2 ...]
# Options:
#   -i, --ignore-case        Ignore case differences.
#   -s, --ignore-spaces      Ignore spaces and line breaks.
#   -p, --ignore-punctuation Ignore punctuation marks.
#   -u, --unicode            Handle Unicode characters.
#   -f, --file FILE          Read strings from a file (one per line).
#       --stdin              Read strings from standard input.
#   -v, --verbose            Enable verbose output.
#   -h, --help               Display this help message.
# Exit status: 0 if the strings are anagrams, 1 if they are not, 2 on usage errors.
# Examples:
#   ./are_anagrams.sh -i "Listen" "Silent"
#   ./are_anagrams.sh -i -s -f strings.txt
#   echo -e "Dormitory\nDirty room" | ./are_anagrams.sh -i --stdin

# Exit immediately if a command exits with a non-zero status.
set -e

# Default configurations
IGNORE_CASE=false
IGNORE_SPACES=false
IGNORE_PUNCTUATION=false
HANDLE_UNICODE=false
VERBOSE=false
INPUT_STRINGS=()
READ_FROM_FILE=false
INPUT_FILE=""
READ_FROM_STDIN=false

# Function to display usage information
usage() {
    echo "Usage: $0 [options] [string1 string2 ...]
Options:
  -i, --ignore-case        Ignore case differences.
  -s, --ignore-spaces      Ignore spaces and line breaks.
  -p, --ignore-punctuation Ignore punctuation marks.
  -u, --unicode            Handle Unicode characters.
  -f, --file FILE          Read strings from a file (one per line).
      --stdin              Read strings from standard input.
  -v, --verbose            Enable verbose output.
  -h, --help               Display this help message."
}

# Function for verbose logging
log() {
    if [[ "$VERBOSE" = true ]]; then
        echo "$1"
    fi
}

# Parse command-line arguments
ARGS=()
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -i|--ignore-case)
            IGNORE_CASE=true
            shift
            ;;
        -s|--ignore-spaces)
            IGNORE_SPACES=true
            shift
            ;;
        -p|--ignore-punctuation)
            IGNORE_PUNCTUATION=true
            shift
            ;;
        -u|--unicode)
            HANDLE_UNICODE=true
            shift
            ;;
        -f|--file)
            if [[ $# -lt 2 ]]; then
                echo "Error: $1 requires a file argument." >&2
                exit 2
            fi
            READ_FROM_FILE=true
            INPUT_FILE="$2"
            shift 2
            ;;
        --stdin)
            READ_FROM_STDIN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            ARGS+=("$@")
            break
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Collect input strings
if [[ "$READ_FROM_FILE" = true ]]; then
    if [[ ! -f "$INPUT_FILE" ]]; then
        echo "Error: File '$INPUT_FILE' not found." >&2
        exit 2
    fi
    mapfile -t INPUT_STRINGS < "$INPUT_FILE"
elif [[ "$READ_FROM_STDIN" = true ]]; then
    mapfile -t INPUT_STRINGS
else
    INPUT_STRINGS+=("${ARGS[@]}")
fi

# Check if at least two strings are provided
if [[ ${#INPUT_STRINGS[@]} -lt 2 ]]; then
    echo "Error: At least two strings must be provided." >&2
    usage >&2
    exit 2
fi

# Function to clean and sort a string
sort_string() {
    local string="$1"

    # Remove spaces if needed
    if [[ "$IGNORE_SPACES" = true ]]; then
        string=$(printf '%s' "$string" | tr -d '[:space:]')
    fi

    # Remove punctuation if needed
    if [[ "$IGNORE_PUNCTUATION" = true ]]; then
        string=$(printf '%s' "$string" | tr -d '[:punct:]')
    fi

    # Convert to lower case if needed
    if [[ "$IGNORE_CASE" = true ]]; then
        if [[ "$HANDLE_UNICODE" = true ]]; then
            # Bash's own lowercasing is multibyte-aware (awk/tr may not be)
            string="${string,,}"
        else
            string=$(printf '%s' "$string" | tr '[:upper:]' '[:lower:]')
        fi
    fi

    # Split into characters (multibyte-aware in a UTF-8 locale), sort bytewise, and reassemble
    printf '%s\n' "$string" | grep -o . | LC_ALL=C sort | tr -d '\n'
}

# Main comparison logic
first_string="${INPUT_STRINGS[0]}"
first_string_sorted=$(sort_string "$first_string")
log "First string sorted: $first_string_sorted"

for ((i=1; i<${#INPUT_STRINGS[@]}; i++)); do
    current_string="${INPUT_STRINGS[i]}"
    current_string_sorted=$(sort_string "$current_string")
    log "Current string sorted: $current_string_sorted"
    if [[ "$first_string_sorted" != "$current_string_sorted" ]]; then
        echo "The strings are not anagrams."
        exit 1
    fi
done

echo "The strings are anagrams."

