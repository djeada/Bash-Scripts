#!/usr/bin/env bash

# Script Name: last_line_empty.sh
# Description: Ensures each file ends with exactly one empty trailing line.
#              Adds a line if missing, removes extras if more than one.
#              Skips binary files. Supports in-place and check-only modes.
# Usage: ./last_line_empty.sh [--check] <path>
# Options:
#   --check  Only detect if changes are needed, do not modify files.
# Examples:
#   ./last_line_empty.sh myfile.txt
#   ./last_line_empty.sh --check myfolder

checkonly=0    # 1 => only check, 0 => fix in place
status=0       # For --check mode: 1 if any file needs fixing

###############################################################################
# process_file: Applies the trailing-empty-line logic to one file.
#   - Skips if not a regular file or if it's binary.
#   - If not skipping, performs (or simulates) the transformation in memory.
#   - Logs everything to stdout.
###############################################################################
process_file() {
    local file="$1"
    echo "Processing: $file"

    # Skip non-regular files:
    if [[ ! -f "$file" ]]; then
        echo "  [ERROR] Not a regular file: $file"
        return 1
    fi

    # Skip binary files:
    if ! grep -Iq . "$file"; then
        echo "  [SKIP] Binary file (not modified)."
        return 0
    fi

    # Read the file into an array, one line per element (mapfile strips the ending newline from each line).
    # This loads everything into memory, which is typically fine for small/medium files.
    # If you have very large files, you'd need a streaming approach, but you explicitly requested these steps.
    mapfile -t lines < "$file"

    local num_lines="${#lines[@]}"

    # Count how many trailing lines are truly empty:
    # We go backward until we find a non-empty line, incrementing empty_count for each empty line.
    local empty_count=0
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

    # Otherwise, we actually fix the file in place.
    # Create a temp file to store the modified content:
    local tmp
    tmp="$(mktemp -t lastline.XXXXXX)"

    # 1. If empty_count == 0, we just print out all lines, then add one empty line.
    # 2. If empty_count > 1, we remove the extras so exactly 1 remains.
    if (( empty_count == 0 )); then
        # Print all lines as is, then add one empty line:
        for line in "${lines[@]}"; do
            echo "$line"
        done
        echo ""
    else
        # empty_count > 1
        # We want to remove empty_count-1 lines from the end, leaving exactly one empty line.
        local keep_until=$(( num_lines - empty_count ))  # index of last non-empty line
        for (( i=0; i<keep_until; i++ )); do
            echo "${lines[$i]}"
        done
        # Now add exactly one empty line
        echo ""
    fi > "$tmp"

    # Replace the original file with the new content:
    mv "$tmp" "$file"
    echo "  [FIXED] File updated (was $empty_count trailing empties)."
}

###############################################################################
# process_directory: Find all regular files in a directory, process each one.
###############################################################################
process_directory() {
    local directory="$1"

    if [[ ! -d "$directory" ]]; then
        echo "Error: $directory is not a directory."
        return 1
    fi

    echo "Recursively processing directory: $directory"
    # Use find to traverse
    while IFS= read -r -d '' f; do
        process_file "$f"
    done < <(find "$directory" -type f -print0 2>/dev/null)
}

###############################################################################
# main
###############################################################################
main() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 [--check] <file-or-directory>"
        exit 1
    fi

    if [[ "$1" == "--check" ]]; then
        checkonly=1
        shift
    fi

    local path="$1"

    if [[ -d "$path" ]]; then
        process_directory "$path"
    elif [[ -f "$path" ]]; then
        process_file "$path"
    else
        echo "Error: '$path' is not a valid file or directory."
        exit 1
    fi

    # If in --check mode and any file needed changes => exit 1
    exit "$status"
}

main "$@"

