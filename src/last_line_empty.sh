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

checkonly=0
status=0

# normalize_file_content outputs the normalized content for a file:
#   - For a non-empty file that isn’t “all whitespace,” it removes any trailing
#     newline(s) and/or trailing whitespace so that the file ends with exactly one newline.
#   - If the file is all whitespace, it normalizes it to a single newline.
#   - Empty files (zero length) are left unchanged.
normalize_file_content() {
    local file="$1"
    perl -0777 -pe '
      # Only process nonempty files.
      if (length($_)) {
         # If the file consists solely of whitespace and newlines,
         # normalize it to just a single newline.
         if ($_ =~ /^[ \t\n]*\z/) {
              $_ = "\n";
         } else {
              if (/\n/) {
                  # If there is at least one newline, remove any extra trailing
                  # newlines and any trailing whitespace after the final newline.
                  s/([ \t]*\n)+[ \t]*\z/\n/;
              } else {
                  # For files that have no newline at the end but may end in spaces/tabs,
                  # remove the trailing whitespace and then append a newline.
                  s/[ \t]+\z//;
                  $_ .= "\n";
              }
         }
      }
    ' "$file"
}

# assert_last_line_empty checks (and optionally fixes) a single file.
assert_last_line_empty() {
    local file="$1"
    echo "Processing file: ${file}"

    if [ ! -f "${file}" ]; then
        echo "Error: ${file} is not a regular file."
        return 1
    fi

    # In check mode, generate the normalized version and compare.
    if [ $checkonly -eq 1 ]; then
        local norm
        norm=$(mktemp)
        normalize_file_content "${file}" > "${norm}"
        if diff -q "${file}" "${norm}" >/dev/null; then
            echo "Already normalized: ${file}"
        else
            echo "Normalization required: ${file}"
            status=1
        fi
        rm -f "${norm}"
    else
        # In fix mode, generate the normalized content and overwrite the file
        # only if there is a change.
        local norm
        norm=$(mktemp)
        normalize_file_content "${file}" > "${norm}"
        if diff -q "${file}" "${norm}" >/dev/null; then
            echo "No changes needed: ${file}"
        else
            mv "${norm}" "${file}"
            echo "File fixed: ${file}"
        fi
        # Clean up any temporary file (if still present).
        [ -f "${norm}" ] && rm -f "${norm}"
    fi
}

process_file() {
    local file="$1"
    assert_last_line_empty "${file}"
}

process_directory() {
    local directory="$1"

    if [ ! -d "${directory}" ]; then
        echo "Error: ${directory} is not a directory."
        return 1
    fi

    echo "Processing directory: ${directory}"
    while IFS= read -r -d '' file; do
        process_file "${file}"
    done < <(find "${directory}" -type f -print0)
}

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

    if [ $status -ne 0 ]; then
        exit 1
    fi
}

main "$@"
