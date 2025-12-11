#!/usr/bin/env bash

# Script Name: convert_to_mp4.sh
# Description: Converts a given video file to MP4 format.
# Usage:       ./convert_to_mp4.sh <file_path>
# Example:     ./convert_to_mp4.sh video.avi

set -o errexit
set -o pipefail
set -o nounset

SCRIPT_NAME=$(basename "$0")

# --- Logging configuration ----------------------------------------------------

LOG_ENABLED=1        # set to 0 to disable logging completely
LOG_FILE=""          # will be determined by init_logging()

init_logging() {
    [ "$LOG_ENABLED" -ne 1 ] && return 0

    # Try these locations in order; first writable one wins
    local candidates=(
        "/var/log/convert_to_mp4.log"
        "$HOME/.local/var/log/convert_to_mp4.log"
        "$HOME/.cache/convert_to_mp4.log"
        "/tmp/convert_to_mp4.log"
    )

    local path dir
    for path in "${candidates[@]}"; do
        dir=$(dirname "$path")

        # Try to create directory if needed
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir" 2>/dev/null || continue
        fi

        # Try to create or touch the log file to test permissions
        if touch "$path" &>/dev/null; then
            LOG_FILE="$path"
            return 0
        fi
    done

    # If we get here, we couldn't log anywhere
    LOG_ENABLED=0
    printf '%s: logging disabled (no writable log location found)\n' "$SCRIPT_NAME" >&2
}

log() {
    [ "$LOG_ENABLED" -ne 1 ] && return 0
    # Best-effort logging; never break the script if logging fails
    {
        printf '%s %s: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$SCRIPT_NAME" "$*"
    } >>"$LOG_FILE" 2>/dev/null || true
}

# --- Utility functions --------------------------------------------------------

fatal() {
    # Print error to stderr, log it, then exit
    local msg="$*"
    printf '%s: error: %s\n' "$SCRIPT_NAME" "$msg" >&2
    log "ERROR: $msg"
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME <input_file>

Converts <input_file> to MP4 using ffmpeg.

- <input_file> can be an absolute or relative path.
- Output file is created in the same directory as <input_file>
  with the same base name and extension ".mp4".

Examples:
  $SCRIPT_NAME video.avi
  $SCRIPT_NAME ./relative/path/video.mkv
EOF
}

# --- Core conversion logic ----------------------------------------------------

convert_to_mp4() {
    local input_path="$1"

    # Resolve to an absolute path
    local input_dir input_base abs_input
    input_dir=$(dirname "$input_path")
    input_base=$(basename "$input_path")
    abs_input="$(cd "$input_dir" && pwd)/$input_base"

    # Derive output file path (same directory, .mp4 extension)
    local filename_no_ext output_file
    filename_no_ext="${input_base%.*}"
    output_file="${input_dir}/${filename_no_ext}.mp4"

    # Resolve output to absolute, too (cosmetic, for messages)
    output_file="$(cd "$input_dir" && pwd)/${filename_no_ext}.mp4"

    log "Starting conversion: '$abs_input' -> '$output_file'"

    printf 'Converting "%s" -> "%s"...\n' "$abs_input" "$output_file"

    # -y to overwrite existing file without interaction (simpler for scripting)
    if ffmpeg -y -i "$abs_input" -vcodec libx264 -acodec aac "$output_file"; then
        printf 'Successfully converted to "%s"\n' "$output_file"
        log "Successfully converted to '$output_file'"
    else
        fatal "ffmpeg conversion failed for '$abs_input'"
    fi
}

# --- Main ---------------------------------------------------------------------

main() {
    init_logging

    # Handle help early
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        usage
        log "Displayed usage information."
        exit 0
    fi

    if [ "$#" -ne 1 ]; then
        usage
        log "Incorrect number of arguments: expected 1, got $#: $*"
        exit 1
    fi

    local file_path="$1"

    # Check for ffmpeg
    if ! command_exists ffmpeg; then
        fatal "ffmpeg is not installed. Please install it and try again."
    fi

    # Check if the file exists
    if [ ! -e "$file_path" ]; then
        fatal "file does not exist: '$file_path'"
    fi

    # Check it's a regular file
    if [ ! -f "$file_path" ]; then
        fatal "path is not a regular file: '$file_path'"
    fi

    # Check readability
    if [ ! -r "$file_path" ]; then
        fatal "file is not readable: '$file_path'"
    fi

    log "Input file validated: '$file_path'"
    convert_to_mp4 "$file_path"
}

main "$@"
