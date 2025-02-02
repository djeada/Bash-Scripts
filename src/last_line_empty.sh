#!/usr/bin/env bash
#
# Script Name: assert_last_line_empty.sh
# Description: Ensures that files end with exactly one trailing empty line.
#              “Empty” here means a line that is either completely empty
#              or contains only whitespace. In particular, if there are multiple
#              trailing empty lines (or lines with only spaces/tabs), they will be
#              squashed to a single trailing empty line.
#
# Usage: assert_last_line_empty.sh [--check] <file_or_directory_path>
#
#        --check : Only check and report problems; do not change files.
#        <file_or_directory_path> : a file or directory to process.
#
# Example: ./assert_last_line_empty.sh --check path/to/file.txt
#

checkonly=0    # Flag indicating if we're only checking (no fixes)
status=0       # Global exit status to track if any file needs fixing

###############################################################################
# normalize_file_content: outputs the normalized content for a file:
#   1. If the file is empty (0 bytes), we output it as-is (no changes).
#   2. If the file is non-empty but contains only whitespace/newlines,
#      we normalize it to exactly one empty line.
#   3. Otherwise, we remove trailing whitespace on every line, remove all
#      trailing blank lines, and then add exactly one trailing newline.
###############################################################################
normalize_file_content() {
    local file="$1"

    # If the file is empty (0 bytes), do nothing:
    if [ ! -s "$file" ]; then
        cat "$file"
        return
    fi

    # Check if the file has any non-whitespace character:
    if ! grep -q '[^[:space:]]' "$file" 2>/dev/null; then
        # The file contains only whitespace / newlines => normalize to one empty line
        printf "\n"
    else
        # 1) Remove trailing spaces/tabs from each line
        # 2) Remove all trailing blank lines
        # 3) Add exactly one newline at the end
        sed 's/[ \t]*$//' "$file" \
        | sed -e ':a' -e '/^$/{$d;N;ba}' \
        ; printf "\n"
    fi
}

###############################################################################
# assert_last_line_empty: Checks (and optionally fixes) a single file.
###############################################################################
assert_last_line_empty() {
    local file="$1"
    echo "Processing file: ${file}"

    if [ ! -f "${file}" ]; then
        echo "Error: ${file} is not a regular file."
        return 1
    fi

    # Create a temporary normalized version of the file
    local norm
    norm="$(mktemp)"

    normalize_file_content "${file}" > "${norm}"

    if [ $checkonly -eq 1 ]; then
        # Compare the normalized file with the original
        if diff -q "${file}" "${norm}" >/dev/null; then
            echo "Already normalized: ${file}"
        else
            echo "Normalization required: ${file}"
            status=1
        fi
        rm -f "${norm}"
    else
        # In fix mode, overwrite the file only if there is a change
        if diff -q "${file}" "${norm}" >/dev/null; then
            echo "No changes needed: ${file}"
            rm -f "${norm}"
        else
            mv "${norm}" "${file}"
            echo "File fixed: ${file}"
        fi
    fi
}

###############################################################################
# process_file: Wrapper to normalize a single file.
###############################################################################
process_file() {
    local file="$1"
    assert_last_line_empty "${file}"
}

###############################################################################
# process_directory: Recursively process all files in a directory.
###############################################################################
process_directory() {
    local directory="$1"

    if [ ! -d "${directory}" ]; then
        echo "Error: ${directory} is not a directory."
        return 1
    fi

    echo "Processing directory: ${directory}"
    # Use find to locate all regular files
    while IFS= read -r -d '' file; do
        process_file "${file}"
    done < <(find "${directory}" -type f -print0)
}

###############################################################################
# main: Script entry point
###############################################################################
main() {
    if [ $# -eq 0 ]; then
        echo "Error: No path provided."
        echo "Usage: $0 [--check] <file_or_directory_path>"
        exit 1
    fi

    if [[ "$1" == "--check" ]]; then
        checkonly=1
        shift
    fi

    local path="$1"

    if [ -d "${path}" ]; then
        process_directory "${path}"
    elif [ -f "${path}" ]; then
        process_file "${path}"
    else
        echo "Error: ${path} is not a valid file or directory."
        exit 1
    fi

    # If any file required normalization in --check mode, exit non-zero
    if [ $status -ne 0 ]; then
        exit 1
    fi
}

main "$@"
