#!/usr/bin/env bash

# Script Name: beautify_script.sh
# Description: Formats shell scripts using Beautysh and analyzes them with ShellCheck.
#              Directories are searched recursively for *.sh files (.git is skipped).
#              The original file mode is preserved when formatting in place.
# Usage: ./beautify_script.sh [--check] <path> [path ...]
# Options:
#   --check  Only check if formatting is needed, do not modify files.
#            Exits 1 if any file needs formatting, cannot be parsed by
#            Beautysh (e.g. indent/outdent mismatch) or fails ShellCheck.
#   <path>   Directory or file to process.
# Example: ./beautify_script.sh ./my_directory

# Ensure tput has something to work with (avoids set -e abort)
export TERM=${TERM:-dumb}

set -euo pipefail

# Color codes for output (graceful fallback when tput fails)
RED="$(tput setaf 1 2>/dev/null || true)"
GREEN="$(tput setaf 2 2>/dev/null || true)"
YELLOW="$(tput setaf 3 2>/dev/null || true)"
CYAN="$(tput setaf 6 2>/dev/null || true)"
RESET="$(tput sgr0 2>/dev/null || true)"

status=0
tmp_file=""

cleanup() {
    [[ -n "$tmp_file" ]] && rm -f "$tmp_file"
    return 0
}
trap cleanup EXIT

log() {
    local color="$1"
    shift
    echo -e "${color}$*${RESET}"
}

err() {
    log "$RED" "$@" >&2
}

usage() {
    echo "Usage: beautify_script.sh [--check] <path> [path ...]" >&2
}

check_tools() {
    local tool
    for tool in beautysh shellcheck; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            err "[ERROR] $tool is not installed."
            exit 1
        fi
    done
}

run_shellcheck() {
    local file="$1"
    local checkonly="$2"
    if ! shellcheck --exclude=SC1091,SC2001 "$file"; then
        err "[SHELLCHECK FAIL] $file"
        status=1
    elif [[ $checkonly -eq 0 ]]; then
        log "$GREEN" "[SHELLCHECK PASS] $file"
    fi
}

format_file() {
    local file="$1"
    local checkonly="$2"
    log "$CYAN" "Processing: $file"

    # Always format via stdin/stdout: beautysh reports parse problems
    # (e.g. "indent/outdent mismatch") with a non-zero exit code, and writing
    # the result back with 'cat >' keeps the original file's mode and inode.
    if ! beautysh - < "$file" > "$tmp_file"; then
        err "[FORMAT ERROR] $file (beautysh could not process it)"
        status=1
    elif ! cmp -s "$tmp_file" "$file"; then
        if [[ $checkonly -eq 1 ]]; then
            log "$YELLOW" "[NEEDS FORMAT] $file"
            status=1
        elif cat "$tmp_file" > "$file"; then
            log "$GREEN" "[FORMATTED] $file"
        else
            err "[FORMAT ERROR] $file (could not write file)"
            status=1
        fi
    elif [[ $checkonly -eq 0 ]]; then
        log "$GREEN" "[ALREADY FORMATTED] $file"
    fi

    run_shellcheck "$file" "$checkonly"
}

process_path() {
    local path="$1"
    local checkonly="$2"
    local file
    if [[ -d "$path" ]]; then
        while IFS= read -r -d '' file; do
            format_file "$file" "$checkonly"
        done < <(find "$path" -name .git -prune -o -type f -name '*.sh' -print0)
    elif [[ -f "$path" ]]; then
        format_file "$path" "$checkonly"
    else
        err "[ERROR] '$path' is not a valid file or directory."
        exit 1
    fi
}

main() {
    local checkonly=0
    if [[ "${1:-}" == "--check" ]]; then
        checkonly=1
        shift
    fi
    if [[ $# -eq 0 ]]; then
        err "[ERROR] No path provided."
        usage
        exit 1
    fi

    check_tools
    tmp_file="$(mktemp)"

    local path
    for path in "$@"; do
        process_path "$path" "$checkonly"
    done

    if [[ $status -ne 0 ]]; then
        err "\nSome files require formatting or have Beautysh/ShellCheck issues."
        exit 1
    fi
    log "$GREEN" "\nAll files are properly formatted and pass ShellCheck."
}

main "$@"

