#!/bin/bash

# clean_comments.sh
# A professional script to remove comments from Python files

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
and removes comments from them.

You can provide a file, directory, or pattern to specify which files to process.
EOF
}

# Logging function
log() {
    local LEVEL="$1"
    shift
    local MESSAGE="$@"
    if [ "$LOG_FILE" ]; then
        echo "[$LEVEL] $MESSAGE" >> "$LOG_FILE"
    fi
    if [ $VERBOSE -eq 1 ]; then
        echo "[$LEVEL] $MESSAGE"
    fi
}

# Check if python3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 could not be found. Please install Python 3 to use this script." >&2
    exit 1
fi

# Parse command-line options using getopts
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
        -b|--backup-ext)
            BACKUP_EXT="$2"
            shift 2
            ;;
        -l|--log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            show_help
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

    # Interactive mode confirmation
    if [ $INTERACTIVE -eq 1 ]; then
        read -p "Remove comments from $FILE? [y/N]: " CONFIRM
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
    cp "$FILE" "$FILE$BACKUP_EXT"
    log "INFO" "Backup created: $FILE$BACKUP_EXT"

    # Use Python to remove comments and docstrings
    python3 - "$FILE" << 'EOF'
import sys
import token
import tokenize

def remove_comments_and_docstrings(source):
    """
    Removes comments and docstrings from Python source code.
    """
    tokens = tokenize.generate_tokens(source.readline)
    result = []
    prev_toktype = token.INDENT
    for tok in tokens:
        tok_type, tok_string, start, end, line = tok
        if tok_type == token.COMMENT:
            continue
        elif tok_type == token.STRING:
            if prev_toktype != token.INDENT:
                continue
            else:
                result.append(tok_string)
        else:
            result.append(tok_string)
        prev_toktype = tok_type
    return ''.join(result)

if __name__ == "__main__":
    try:
        filename = sys.argv[1]
        with open(filename, 'r') as f:
            source = f.read()
        from io import StringIO
        cleaned_code = remove_comments_and_docstrings(StringIO(source))
        with open(filename, 'w') as f:
            f.write(cleaned_code)
    except Exception as e:
        print(f"Error processing {filename}: {e}", file=sys.stderr)
        sys.exit(1)
EOF

    if [ $? -eq 0 ]; then
        log "INFO" "Comments removed from $FILE"
    else
        log "ERROR" "Failed to remove comments from $FILE"
    fi
}

# Function to find and process files
find_and_process_files() {
    local TARGET="$1"

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
        local FILES=($TARGET)
        if [ ${#FILES[@]} -eq 0 ]; then
            log "WARNING" "No files matched pattern: $TARGET"
        else
            for FILE in "${FILES[@]}"; do
                if [ -e "$FILE" ]; then
                    process_file "$FILE"
                else
                    log "WARNING" "File does not exist: $FILE"
                fi
            done
        fi
        shopt -u nullglob
    fi
}

# Main processing loop
for TARGET in "${TARGETS[@]}"; do
    find_and_process_files "$TARGET"
done

