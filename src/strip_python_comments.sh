#!/usr/bin/env bash

# Script Name: strip_python_comments.sh
# Description: Removes comments from Python files with support for interactive mode,
#              verbose output, dry-run, backups, and logging. Strings, docstrings,
#              the shebang line and the encoding declaration are left untouched.
# Usage: ./strip_python_comments.sh [options] [file|directory|pattern]
# Options:
#   -i, --interactive      Ask for confirmation before removing comments from each file.
#   -v, --verbose          Enable verbose output.
#   -n, --dry-run          Perform a trial run without making any changes.
#   -b, --backup-ext EXT   Specify backup file extension (default: .bak).
#   -l, --log-file FILE    Log output to the specified file.
#   -h, --help             Display the help message.

# Exit immediately if a command exits with a non-zero status
set -e

# Initialize variables
INTERACTIVE=0
VERBOSE=0
DRY_RUN=0
LOG_FILE=""
BACKUP_EXT=".bak"
TARGETS=()

# Function to display help message
show_help() {
    cat << EOF
Usage: $(basename "$0") [options] [file|directory|pattern]

Options:
  -i, --interactive      Ask for confirmation before removing comments from each file
  -v, --verbose          Enable verbose output
  -n, --dry-run          Perform a trial run without making any changes
  -b, --backup-ext EXT   Specify backup file extension (default: .bak)
  -l, --log-file FILE    Log output to the specified file
  -h, --help             Display this help message

By default, the script finds all .py files in the current directory and subdirectories,
and removes comments from them. The shebang line and encoding declaration are kept;
strings and docstrings are left untouched. A backup of every modified file is created.

You can provide a file, directory, or pattern to specify which files to process.
EOF
}

# Logging function: errors and warnings always go to stderr, other messages only with --verbose
log() {
    local LEVEL="$1"
    shift
    local MESSAGE="$*"
    if [ "$LOG_FILE" ]; then
        echo "[$LEVEL] $MESSAGE" >> "$LOG_FILE"
    fi
    if [[ "$LEVEL" == "ERROR" || "$LEVEL" == "WARNING" ]]; then
        echo "[$LEVEL] $MESSAGE" >&2
    elif [ $VERBOSE -eq 1 ]; then
        echo "[$LEVEL] $MESSAGE"
    fi
}

# Check if python3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 could not be found. Please install Python 3 to use this script." >&2
    exit 1
fi

# Parse command-line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--interactive)
            INTERACTIVE=1
            shift
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=1
            shift
            ;;
        -b|--backup-ext|-l|--log-file)
            if [[ $# -lt 2 || -z "$2" ]]; then
                echo "Error: $1 requires a non-empty argument." >&2
                exit 1
            fi
            if [[ "$1" == -b || "$1" == --backup-ext ]]; then
                BACKUP_EXT="$2"
            else
                LOG_FILE="$2"
            fi
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            show_help >&2
            exit 1
            ;;
        *)
            TARGETS+=("$1")
            shift
            ;;
    esac
done

# If no targets specified, default to current directory
if [ ${#TARGETS[@]} -eq 0 ]; then
    TARGETS=(".")
fi

# Function to process a single file
process_file() {
    local FILE="$1"

    # Ensure the file has a .py extension
    if [[ "$FILE" != *.py ]]; then
        return
    fi

    # Check if the file is readable
    if [ ! -r "$FILE" ]; then
        log "ERROR" "Cannot read file: $FILE"
        return
    fi

    # Interactive mode confirmation (read from the terminal, not from the file list)
    if [ $INTERACTIVE -eq 1 ]; then
        read -rp "Remove comments from $FILE? [y/N]: " CONFIRM < /dev/tty || CONFIRM=""
        if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
            log "INFO" "Skipping $FILE"
            return
        fi
    fi

    # Dry-run mode
    if [ $DRY_RUN -eq 1 ]; then
        log "INFO" "Would process file: $FILE"
        return
    fi

    # Create a backup of the file
    if ! cp -p -- "$FILE" "$FILE$BACKUP_EXT"; then
        log "ERROR" "Could not create backup of $FILE; skipping it"
        return
    fi
    log "INFO" "Backup created: $FILE$BACKUP_EXT"

    # Use Python's tokenizer to find comments, so '#' inside strings is left alone.
    # Only the comment text is cut from each line; all other code is kept byte-for-byte.
    if python3 - "$FILE" << 'EOF'
import io
import re
import sys
import tokenize


def remove_comments(source):
    lines = io.StringIO(source, newline="").readlines()
    reader = io.StringIO(source, newline="").readline
    for tok in tokenize.generate_tokens(reader):
        if tok.type != tokenize.COMMENT:
            continue
        row, col = tok.start
        idx = row - 1
        text = lines[idx]
        # Keep the shebang and the encoding declaration
        if idx == 0 and text.startswith("#!"):
            continue
        if idx < 2 and col == 0 and re.match(r"^#.*coding[:=]", text):
            continue
        ending = text[len(text.rstrip("\r\n")):]
        code = text[:col].rstrip()
        # Drop lines that contained nothing but a comment
        lines[idx] = code + ending if code else ""
    return "".join(lines)


filename = sys.argv[1]
try:
    with open(filename, "rb") as f:
        raw = f.read()
    encoding, _ = tokenize.detect_encoding(io.BytesIO(raw).readline)
    cleaned_code = remove_comments(raw.decode(encoding))
    with open(filename, "wb") as f:
        f.write(cleaned_code.encode(encoding))
except Exception as e:
    print(f"Error processing {filename}: {e}", file=sys.stderr)
    sys.exit(1)
EOF
    then
        log "INFO" "Comments removed from $FILE"
    else
        log "ERROR" "Failed to remove comments from $FILE"
    fi
}

# Function to find and process files
find_and_process_files() {
    local TARGET="$1"
    local FILE

    if [ -f "$TARGET" ]; then
        process_file "$TARGET"
    elif [ -d "$TARGET" ]; then
        # Find all .py files in the directory
        while IFS= read -r -d '' FILE; do
            process_file "$FILE"
        done < <(find "$TARGET" -type f -name "*.py" -print0)
    else
        # Assume it's a pattern
        shopt -s nullglob
        # shellcheck disable=SC2206
        local FILES=($TARGET)
        shopt -u nullglob
        if [ ${#FILES[@]} -eq 0 ]; then
            log "WARNING" "No files matched pattern: $TARGET"
        else
            for FILE in "${FILES[@]}"; do
                if [ -f "$FILE" ]; then
                    process_file "$FILE"
                else
                    log "WARNING" "Not a regular file: $FILE"
                fi
            done
        fi
    fi
}

# Main processing loop
for TARGET in "${TARGETS[@]}"; do
    find_and_process_files "$TARGET"
done

