#!/usr/bin/env bash
#
# assert_last_line_empty.sh
#
# Ensures that each (text) file ends with exactly one trailing empty line,
# matching the original Perl logic:
#   - If the file is empty (0 bytes), leave it empty.
#   - If the file contains only whitespace/newlines, replace it with exactly
#     one blank line (a single "\n").
#   - Otherwise:
#       * Strip trailing spaces/tabs from each line.
#       * Remove multiple trailing blank lines, leaving only one.
#       * If there was no final newline at all, add one.
#
# Binary files are skipped.
#
# Usage: ./assert_last_line_empty.sh [--check] <file-or-directory>
#   --check   : Only report which files need changes; do not modify.
#   <path>    : File or directory to process.
#

checkonly=0   # 1 if we only check (report), 0 if we actually fix
status=0      # Will be set to 1 if any file requires fixing in --check mode

###############################################################################
# normalize_file_content
#   Reads a file $1 and prints its normalized content to stdout:
#     1) If empty => print nothing (stay empty).
#     2) If file is all whitespace => print exactly one "\n".
#     3) Else => remove trailing spaces, remove trailing blank lines,
#                then end with exactly one "\n".
###############################################################################
normalize_file_content() {
    local file="$1"

    # If empty file (0 bytes), output as-is (which is nothing):
    if [ ! -s "$file" ]; then
        cat "$file"
        return
    fi

    # If the file has no non-whitespace characters => turn into one blank line:
    if ! grep -q '[^[:space:]]' "$file" 2>/dev/null; then
        printf "\n"
        return
    fi

    # Otherwise, file has real content:
    #
    # 1) Remove trailing spaces/tabs from each line.
    # 2) Remove *all* trailing blank lines.
    # 3) Finally, add exactly one newline at the end.

    sed 's/[ \t]*$//' "$file" \
      | sed -e ':a' -e '/^$/{$d;N;ba}' \
      && printf "\n"
}

###############################################################################
# assert_last_line_empty
#   Checks (and possibly fixes) a single file to ensure it meets our policy.
###############################################################################
assert_last_line_empty() {
    local file="$1"
    echo "Processing: $file"

    # Skip if not a regular file:
    if [ ! -f "$file" ]; then
        echo "  [ERROR] Not a regular file: $file"
        return 1
    fi

    # Skip if binary:
    if ! grep -Iq . "$file"; then
        echo "  [SKIP] Binary file: $file"
        return 0
    fi

    # Create a temporary normalized version:
    local tmp
    tmp="$(mktemp -t assert_last_line_empty.XXXXXX)"
    normalize_file_content "$file" > "$tmp"

    # Compare:
    if diff -q "$file" "$tmp" >/dev/null; then
        echo "  [OK] Already normalized."
        rm -f "$tmp"
    else
        if [ "$checkonly" -eq 1 ]; then
            echo "  [CHECK] Needs normalization."
            status=1
            rm -f "$tmp"
        else
            mv "$tmp" "$file"
            echo "  [FIXED] File updated."
        fi
    fi
}

###############################################################################
# process_directory
#   Recursively processes all regular files in a given directory.
###############################################################################
process_directory() {
    local directory="$1"

    if [ ! -d "$directory" ]; then
        echo "Error: $directory is not a directory."
        return 1
    fi

    echo "Recursively processing directory: $directory"
    find "$directory" -type f -print0 2>/dev/null \
    | while IFS= read -r -d '' f; do
        assert_last_line_empty "$f"
    done
}

###############################################################################
# main
###############################################################################
main() {
    if [ $# -eq 0 ]; then
        echo "Usage: $0 [--check] <file-or-directory>"
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

    # If in --check mode and anything needs changes => exit 1
    exit "$status"
}

main "$@"
