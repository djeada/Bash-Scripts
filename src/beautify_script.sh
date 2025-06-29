# hooks/beautify_script.sh
#!/usr/bin/env bash

# Ensure tput has something to work with (avoids set -e abort)
export TERM=${TERM:-dumb}

# Script Name: beautify_script.sh
# Description: Formats shell scripts using Beautysh and analyzes them with ShellCheck.
# Usage: beautify_script.sh [--check] <path>
#        --check - Only check if formatting is needed, do not modify files.
#        <path>  - Directory or file to process.
# Example: ./beautify_script.sh ./my_directory

set -euo pipefail

# Color codes for output
RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
YELLOW="$(tput setaf 3)"
CYAN="$(tput setaf 6)"
RESET="$(tput sgr0)"

status=0

log() {
    local color="$1"; shift
    echo -e "${color}$*${RESET}"
}

check_tools() {
    command -v beautysh >/dev/null 2>&1 || { log "$RED" "[ERROR] beautysh is not installed."; exit 1; }
    command -v shellcheck >/dev/null 2>&1 || { log "$RED" "[ERROR] shellcheck is not installed."; exit 1; }
}

format_file() {
    local file="$1"
    local checkonly="$2"
    log "$CYAN" "Processing: $file"

    if [[ $checkonly -eq 1 ]]; then
        # Check formatting
        if ! diff -q <(beautysh - < "$file") "$file" >/dev/null; then
            log "$YELLOW" "[NEEDS FORMAT] $file"
            status=1
        fi
        # ShellCheck analysis
        if ! shellcheck --exclude=SC1091,SC2001 "$file"; then
            log "$RED" "[SHELLCHECK FAIL] $file"
            status=1
        fi
    else
        # Format in place
        if ! beautysh "$file"; then
            log "$RED" "[FORMAT ERROR] $file"
            status=1
        else
            log "$GREEN" "[FORMATTED] $file"
        fi
        # ShellCheck analysis
        if ! shellcheck --exclude=SC1091,SC2001 "$file"; then
            log "$RED" "[SHELLCHECK FAIL] $file"
            status=1
        else
            log "$GREEN" "[SHELLCHECK PASS] $file"
        fi
    fi
}

process_path() {
    local path="$1"
    local checkonly="$2"
    if [ -d "$path" ]; then
        find "$path" -type f -name '*.sh' -print0 | while IFS= read -r -d '' file; do
            format_file "$file" "$checkonly"
        done
    elif [ -f "$path" ]; then
        format_file "$path" "$checkonly"
    else
        log "$RED" "[ERROR] '$path' is not a valid file or directory."
        exit 1
    fi
}

main() {
    check_tools
    local checkonly=0
    if [[ $# -eq 0 ]]; then
        log "$RED" "[ERROR] No path provided."
        echo "Usage: beautify_script.sh [--check] <path>"
        exit 1
    fi
    if [[ $1 == "--check" ]]; then
        checkonly=1
        shift
    fi
    process_path "$1" "$checkonly"
    if [[ $status -eq 1 ]]; then
        log "$RED" "\nSome files require formatting or have ShellCheck issues."
        exit 1
    else
        log "$GREEN" "\nAll files are properly formatted and pass ShellCheck."
    fi
}

main "$@"
