#!/usr/bin/env bash

# Script Name: last_line_empty.sh
# Description: Ensures each file ends with exactly one empty trailing line.
#              Adds a line if missing, removes extras if more than one.
#              Skips binary files and .git directories. Supports in-place
#              (permission-preserving) and check-only modes.
# Usage: ./last_line_empty.sh [--check] <path>
# Options:
#   --check  Only detect if changes are needed, do not modify files.
# Examples:
#   ./last_line_empty.sh myfile.txt
#   ./last_line_empty.sh --check myfolder

checkonly=0    # 1 => only check, 0 => fix in place
status=0       # 1 if any file needs fixing (--check mode) or an error occurred

###############################################################################
# process_file: Applies the trailing-empty-line logic to one file.
#   - Skips if not a regular file or if it's binary.
#   - If not skipping, performs (or simulates) the transformation in memory.
#   - Logs progress to stdout, errors to stderr.
###############################################################################
process_file() {
    local file="$1"
    echo "Processing: $file"

    # Skip non-regular files:
    if [[ ! -f "$file" ]]; then
        echo "  [ERROR] Not a regular file: $file" >&2
        return 1
    fi

    # Skip binary files:
    if ! grep -Iq . "$file"; then
        echo "  [SKIP] Binary file (not modified)."
        return 0
    fi

    # Read the file into an array, one line per element (mapfile strips the
    # newline from each line). Fine for the small/medium text files this targets.
    local lines=()
    mapfile -t lines < "$file"

    local num_lines="${#lines[@]}"

    # Count how many trailing lines are truly empty:
    # We go backward until we find a non-empty line, incrementing empty_count for each empty line.
    local empty_count=0 i
    for (( i = num_lines - 1; i >= 0; i-- )); do
        if [[ -z "${lines[$i]}" ]]; then
            (( empty_count++ ))
        else
            break
        fi
    done

    # Decide how we want to transform:
    #   - If empty_count == 0 => add one empty line
    #   - If empty_count == 1 => do nothing
    #   - If empty_count > 1  => remove extras so we end up with exactly 1
    local need_change=0
    if (( empty_count == 0 )); then
        # We'll add one new empty line at the end
        need_change=1
    elif (( empty_count > 1 )); then
        # We'll remove extra empty lines so exactly one remains
        need_change=1
    fi

    if (( need_change == 0 )); then
        echo "  [OK] Already correct (# of trailing empty lines = 1)."
        return 0
    fi

    # If we *would* change the file, see if we're in check mode:
    if (( checkonly == 1 )); then
        echo "  [CHECK] Needs changes (trailing empty lines = $empty_count)."
        status=1
        return 0
    fi

    # Otherwise, fix the file in place: keep everything up to the last non-empty
    # line, then add exactly one empty line. Writing through the existing file
    # (instead of replacing it) preserves its permissions and ownership.
    local keep_until=$(( num_lines - empty_count ))  # number of lines to keep
    if ! printf '%s\n' "${lines[@]:0:keep_until}" "" > "$file"; then
        echo "  [ERROR] Failed to write $file" >&2
        return 1
    fi
    echo "  [FIXED] File updated (was $empty_count trailing empties)."
}

###############################################################################
# process_directory: Find all regular files in a directory, process each one.
###############################################################################
process_directory() {
    local directory="$1"

    if [[ ! -d "$directory" ]]; then
        echo "Error: $directory is not a directory." >&2
        return 1
    fi

    echo "Recursively processing directory: $directory"
    # Use find to traverse, skipping .git directories
    local f
    while IFS= read -r -d '' f; do
        process_file "$f" || status=1
    done < <(find "$directory" -name .git -prune -o -type f -print0)
}

###############################################################################
# main
###############################################################################
main() {
    if [[ "${1:-}" == "--check" ]]; then
        checkonly=1
        shift
    fi

    if [[ $# -ne 1 ]]; then
        echo "Usage: $0 [--check] <file-or-directory>" >&2
        exit 1
    fi

    local path="$1"

    if [[ -d "$path" ]]; then
        process_directory "$path"
    elif [[ -f "$path" ]]; then
        process_file "$path" || status=1
    else
        echo "Error: '$path' is not a valid file or directory." >&2
        exit 1
    fi

    # Exit 1 if any file needed changes (--check mode) or could not be processed
    exit "$status"
}

main "$@"

