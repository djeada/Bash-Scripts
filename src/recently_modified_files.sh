#!/usr/bin/env bash

# Script Name: recently_modified_files.sh
# Description: Lists the most recently modified (or accessed/changed) files in a
#              directory tree, with filtering and sorting options. Requires GNU find.
# Usage: recently_modified_files.sh [options]
#
# Options:
#   -d, --directory DIR       Specify the directory to search (default: current directory).
#   -n, --number N            Number of files to list (default: 10).
#   -t, --time TYPE           Time to sort by: mtime (modification), atime (access), ctime (change) (default: mtime).
#   -r, --reverse             Reverse the sort order.
#   -e, --exclude PATTERN     Exclude files matching PATTERN.
#   -i, --include PATTERN     Include only files matching PATTERN.
#   -l, --log-file FILE       Log output to specified file.
#   -v, --verbose             Enable verbose output.
#   -h, --help                Display this help message.
#
# Examples:
#   recently_modified_files.sh -d /home/user/documents -n 5
#   recently_modified_files.sh --time atime --reverse
#   recently_modified_files.sh -i '*.txt' -e '*.log'

set -euo pipefail

# Default configurations
DIRECTORY="."
NUMBER=10
TIME_TYPE="mtime"
REVERSE=false
EXCLUDE_PATTERN=""
INCLUDE_PATTERN=""
LOG_FILE=""
VERBOSE=false

# Function to display usage information
usage() {
    cat << EOF
Usage: $0 [options]

Options:
  -d, --directory DIR       Specify the directory to search (default: current directory).
  -n, --number N            Number of files to list (default: 10).
  -t, --time TYPE           Time to sort by: mtime (modification), atime (access), ctime (change) (default: mtime).
  -r, --reverse             Reverse the sort order.
  -e, --exclude PATTERN     Exclude files matching PATTERN.
  -i, --include PATTERN     Include only files matching PATTERN.
  -l, --log-file FILE       Log output to specified file.
  -v, --verbose             Enable verbose output.
  -h, --help                Display this help message.

Examples:
  $0 -d /home/user/documents -n 5
  $0 --time atime --reverse
  $0 -i '*.txt' -e '*.log'

EOF
}

# Function for logging
log() {
    local message="$1"
    if [[ "$VERBOSE" == true ]]; then
        echo "$message"
    fi
    if [[ -n "$LOG_FILE" ]]; then
        echo "$message" >> "$LOG_FILE"
    fi
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -d|--directory)
            if [[ -n "${2-}" ]]; then
                DIRECTORY="$2"
                shift 2
            else
                echo "Error: --directory requires a non-empty argument." >&2
                exit 1
            fi
            ;;
        -n|--number)
            if [[ -n "${2-}" ]]; then
                NUMBER="$2"
                shift 2
            else
                echo "Error: --number requires a non-empty argument." >&2
                exit 1
            fi
            ;;
        -t|--time)
            if [[ -n "${2-}" ]]; then
                TIME_TYPE="$2"
                shift 2
            else
                echo "Error: --time requires a non-empty argument." >&2
                exit 1
            fi
            ;;
        -r|--reverse)
            REVERSE=true
            shift
            ;;
        -e|--exclude)
            if [[ -n "${2-}" ]]; then
                EXCLUDE_PATTERN="$2"
                shift 2
            else
                echo "Error: --exclude requires a non-empty argument." >&2
                exit 1
            fi
            ;;
        -i|--include)
            if [[ -n "${2-}" ]]; then
                INCLUDE_PATTERN="$2"
                shift 2
            else
                echo "Error: --include requires a non-empty argument." >&2
                exit 1
            fi
            ;;
        -l|--log-file)
            if [[ -n "${2-}" ]]; then
                LOG_FILE="$2"
                shift 2
            else
                echo "Error: --log-file requires a non-empty argument." >&2
                exit 1
            fi
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
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

# Validate directory
if [[ ! -d "$DIRECTORY" ]]; then
    echo "Error: Directory '$DIRECTORY' does not exist." >&2
    exit 1
fi

# Validate number
if ! [[ "$NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: The number of files to list must be a positive integer." >&2
    exit 1
fi

# Validate time type
if [[ "$TIME_TYPE" != "mtime" && "$TIME_TYPE" != "atime" && "$TIME_TYPE" != "ctime" ]]; then
    echo "Error: Invalid time type '$TIME_TYPE'. Must be 'mtime', 'atime', or 'ctime'." >&2
    exit 1
fi

# Build find command
FIND_CMD=(find "$DIRECTORY" -type f)

# Include pattern
if [[ -n "$INCLUDE_PATTERN" ]]; then
    FIND_CMD+=(-name "$INCLUDE_PATTERN")
fi

# Exclude pattern
if [[ -n "$EXCLUDE_PATTERN" ]]; then
    FIND_CMD+=(! -name "$EXCLUDE_PATTERN")
fi

# Determine time format
case "$TIME_TYPE" in
    mtime) TIME_FORMAT='%TY-%Tm-%Td %TT %p\n' ;;
    atime) TIME_FORMAT='%AY-%Am-%Ad %AT %p\n' ;;
    ctime) TIME_FORMAT='%CY-%Cm-%Cd %CT %p\n' ;;
esac

# Build the full command (GNU find is required for -printf)
FIND_CMD+=(-printf "$TIME_FORMAT")

log "Executing command: ${FIND_CMD[*]}"

# Execute find command and sort results (newest first unless --reverse)
SORT_OPTS=()
if [[ "$REVERSE" != true ]]; then
    SORT_OPTS=(-r)
fi

# Unreadable subdirectories make find exit non-zero; report them but keep the
# results. awk (unlike head) reads all input, so sort never dies of SIGPIPE.
RESULTS=$( { "${FIND_CMD[@]}" || true; } | sort "${SORT_OPTS[@]}" | awk -v n="$NUMBER" 'NR <= n' )

# Output results
if [[ "$REVERSE" == true ]]; then
    echo "Files in '$DIRECTORY' by $TIME_TYPE (oldest first):"
else
    echo "Files in '$DIRECTORY' by $TIME_TYPE (newest first):"
fi
if [[ -n "$RESULTS" ]]; then
    echo "$RESULTS"
else
    echo "No matching files found."
fi

# Log results
log "Found files:"
log "$RESULTS"

