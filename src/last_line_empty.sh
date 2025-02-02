#!/usr/bin/env bash
#
# Script Name: assert_last_line_empty.sh
# Description: Ensures that text files end with exactly one trailing newline,
#              collapsing multiple trailing empty lines (containing only
#              whitespace/tabs/newlines) down to a single newline. Files
#              that are empty (0 bytes) are unchanged; files containing only
#              whitespace become a single blank line; binary files are skipped.
#
# Usage:       assert_last_line_empty.sh [--check] <file_or_directory_path>
#   --check : Only check and report problems; do not change files.
#   <file_or_directory_path> : A file or directory to process.
#
# Example:     ./assert_last_line_empty.sh --check path/to/file.txt
#

checkonly=0    # Flag to indicate we only check (no fixes)
status=0       # Will become 1 if any file needs changes in --check mode

###############################################################################
# normalize_file_content
#   - If empty file (0 bytes), output as is (no change).
#   - If file contains only whitespace, collapse to a single newline.
#   - Otherwise (it has non-whitespace):
#       * Remove trailing spaces/tabs on each line.
#       * If file has no newline at all, add exactly one.
#       * If file has at least one newline, remove any extra trailing
#         blank lines (including whitespace-only lines) so that we
#         end with exactly one newline.
###############################################################################
normalize_file_content() {
    local file="$1"

    # 1) If empty, do nothing:
    if [ ! -s "$file" ]; then
        cat "$file"        # or just 'return' if you prefer truly empty
        return
    fi

    # 2) If file is all whitespace (spaces/tabs/newlines):
    if ! grep -q '[^[:space:]]' "$file" 2>/dev/null; then
        # Collapse it to a single newline:
        printf "\n"
        return
    fi

    # 3) If the file has no newline at all:
    if ! grep -q $'\n' "$file"; then
        # Remove trailing spaces/tabs, then add exactly one newline:
        sed 's/[ \t]*$//' "$file"
        printf "\n"
        return
    fi

    # 4) File has non-whitespace *and* at least one newline:
    #    - Remove trailing spaces/tabs from each line
    #    - Remove all trailing empty lines
    #    - End with exactly one newline
    sed 's/[ \t]*$//' "$file" \
      | sed -e ':a' -e '/^[[:space:]]*$/N; /^\n*$/ba'
    printf "\n"
}

###############################################################################
# assert_last_line_empty
#   - Checks (and optionally fixes) a single file.
#   - Skips binary files (by checking if grep thinks it is binary).
#   - Logs changes.
###############################################################################
assert_last_line_empty() {
    local file="$1"
    echo "Processing file: $file"

    # Skip if not a regular file:
    if [ ! -f "$file" ]; then
        echo "  [ERROR] Not a regular file: $file"
        return 1
    fi

    # Skip if binary:
    if ! grep -Iq . "$file"; then
        echo "  [SKIP] Binary file (not modified): $file"
        return 0
    fi

    # Create temporary normalized version of the file
    local tmp norm
    tmp="$(mktemp -t assert_last_line_empty.XXXXXX)"

    normalize_file_content "$file" > "$tmp"

    # Compare to see if changes needed:
    if diff -q "$file" "$tmp" >/dev/null; then
        echo "  [OK] No changes needed: $file"
        rm -f "$tmp"
    else
        if [ "$checkonly" -eq 1 ]; then
            echo "  [CHECK] Normalization required: $file"
            status=1
            rm -f "$tmp"
        else
            mv "$tmp" "$file"
            echo "  [FIXED] File updated: $file"
        fi
    fi
}

###############################################################################
# process_directory
#   - Recursively process all regular files in a directory.
###############################################################################
process_directory() {
    local directory="$1"

    if [ ! -d "$directory" ]; then
        echo "Error: $directory is not a directory."
        return 1
    fi

    echo "Recursively processing directory: $directory"
    find "$directory" -type f -print0 2>/dev/null \
    | while IFS= read -r -d '' file; do
        assert_last_line_empty "$file"
    done
}

###############################################################################
# main: entry point
###############################################################################
main() {
    if [ $# -eq 0 ]; then
        echo "Usage: $0 [--check] <file_or_directory_path>"
        exit 1
    fi

    if [[ "$1" == "--check" ]]; then
        checkonly=1
        shift
    fi

    local path="$1"
    if [ -d "$path" ]; then
        process_directory "$path"
    elif [ -f "$path" ]; then
        assert_last_line_empty "$path"
    else
        echo "Error: $path is not a valid file or directory."
        exit 1
    fi

    # If in --check mode, and we found at least one file needing changes, exit 1
    exit "$status"
}

main "$@"
