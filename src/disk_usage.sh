#!/usr/bin/env bash

# Script Name: disk_usage.sh
# Description: Computes and displays disk usage for the system with advanced options.
# Usage: disk_usage.sh [options]
#
# Options:
#   -h, --help                Display this help message and exit.
#   -v, --verbose             Enable verbose output.
#   -V, --version             Display script version and exit.
#   -p, --pattern PATTERN     Specify disk pattern to match (e.g., 'sda').
#   -e, --exclude PATTERN     Exclude disks matching the pattern.
#   -t, --type TYPE           Include only filesystems of specified type (e.g., 'ext4').
#   -a, --all                 Include all filesystems (including tmpfs, udev, etc.).
#   -s, --sort FIELD          Sort output by field (filesystem, size, used, avail, use%, mount).
#   -r, --reverse             Reverse the sort order.
#   -o, --output FILE         Save output to specified file (overwritten) and print it.
#       --json                Output in JSON format.
#       --csv                 Output in CSV format.
#       --no-header           Do not display header row.
#   -l, --log-file FILE       Log output to specified file.
#
# Examples:
#   disk_usage.sh -p sda
#   disk_usage.sh --type ext4
#   disk_usage.sh --all --verbose
#   disk_usage.sh --json --output usage.json

set -euo pipefail

VERSION="1.0.0"

# Default configurations
VERBOSE=false
DISK_PATTERN=""
EXCLUDE_PATTERN=""
FILESYSTEM_TYPE=""
INCLUDE_ALL=false
SORT_FIELD=""
REVERSE_SORT=false
OUTPUT_FILE=""
OUTPUT_JSON=false
OUTPUT_CSV=false
NO_HEADER=false
LOG_FILE=""
LOG_ENABLED=false

# Function to display usage information
print_usage() {
    cat << EOF
Usage: $0 [options]

Options:
  -h, --help                Display this help message and exit.
  -v, --verbose             Enable verbose output.
  -V, --version             Display script version and exit.
  -p, --pattern PATTERN     Specify disk pattern to match (e.g., 'sda').
  -e, --exclude PATTERN     Exclude disks matching the pattern.
  -t, --type TYPE           Include only filesystems of specified type (e.g., 'ext4').
  -a, --all                 Include all filesystems (including tmpfs, udev, etc.).
  -s, --sort FIELD          Sort output by field (filesystem, size, used, avail, use%, mount).
  -r, --reverse             Reverse the sort order.
  -o, --output FILE         Save output to specified file (overwritten) and print it.
      --json                Output in JSON format.
      --csv                 Output in CSV format.
      --no-header           Do not display header row.
  -l, --log-file FILE       Log output to specified file.

Examples:
  $0 -p sda
  $0 --type ext4
  $0 --all --verbose
  $0 --json --output usage.json
EOF
}

# Function to display version information
print_version() {
    echo "$0 version $VERSION"
}

# Function for logging
log_action() {
    local message="$1"
    if [[ "$LOG_ENABLED" == true ]]; then
        echo "$(date +"%Y-%m-%d %T"): $message" >> "$LOG_FILE"
    fi
    if [[ "$VERBOSE" == true ]]; then
        echo "$message"
    fi
}

# Sort tab-separated rows according to SORT_FIELD / REVERSE_SORT
sort_rows() {
    local key=""
    case "$SORT_FIELD" in
        filesystem) key="1,1" ;;
        size)       key="2,2h" ;;
        used)       key="3,3h" ;;
        avail)      key="4,4h" ;;
        use%)       key="5,5n" ;;
        mount)      key="6,6" ;;
    esac

    # A key with its own modifiers ignores a global -r, so attach r to the key
    if [[ -n "$key" && "$REVERSE_SORT" == true ]]; then
        LC_ALL=C sort -t $'\t' -k "${key}r"
    elif [[ -n "$key" ]]; then
        LC_ALL=C sort -t $'\t' -k "$key"
    elif [[ "$REVERSE_SORT" == true ]]; then
        LC_ALL=C sort -r
    else
        cat
    fi
}

# Function to list disk partitions and usage
list_disks() {
    # -P: one line per filesystem, -T: include the filesystem type column
    local df_args=(-P -T -h)
    if [[ "$INCLUDE_ALL" == true ]]; then
        df_args+=(-a)
    fi

    # Filter the rows (patterns are passed as awk variables, not spliced into
    # the program) and emit tab-separated fields:
    # filesystem, size, used, avail, use%, mount point (which may contain spaces)
    # LC_ALL=C keeps "." as the decimal separator (sizes like 6.2M stay CSV-safe).
    # df exits non-zero when a single mount cannot be read (common with -a);
    # report it on stderr but still show the rest
    local awk_vars=(-v all="$INCLUDE_ALL" -v type="$FILESYSTEM_TYPE" -v pat="$DISK_PATTERN" -v excl="$EXCLUDE_PATTERN")
    { LC_ALL=C df "${df_args[@]}" || true; } | awk "${awk_vars[@]}" '
        NR == 1 { next }
        all != "true" && ($2 == "tmpfs" || $2 == "devtmpfs" || $1 ~ /^udev/) { next }
        type != "" && $2 != type { next }
        pat != "" && $1 !~ pat { next }
        excl != "" && $1 ~ excl { next }
        {
            mount = $7
            for (i = 8; i <= NF; i++) mount = mount " " $i
            printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, $3, $4, $5, $6, mount
        }' | sort_rows | format_rows
}

# Format tab-separated rows as JSON, CSV or an aligned table
format_rows() {
    if [[ "$OUTPUT_JSON" == true ]]; then
        awk -F'\t' '
            function esc(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); return s }
            BEGIN { ORS=""; print "[" }
            {
                if (NR > 1) print ","
                printf "{ \"filesystem\": \"%s\", \"size\": \"%s\", \"used\": \"%s\", \"avail\": \"%s\", \"use%%\": \"%s\", \"mount\": \"%s\" }", esc($1), $2, $3, $4, $5, esc($6)
            }
            END { print "]\n" }'
    elif [[ "$OUTPUT_CSV" == true ]]; then
        if [[ "$NO_HEADER" == false ]]; then
            echo "Filesystem,Size,Used,Avail,Use%,Mounted on"
        fi
        awk -F'\t' -v OFS=',' '{ print $1, $2, $3, $4, $5, $6 }'
    else
        {
            if [[ "$NO_HEADER" == false ]]; then
                printf 'Filesystem\tSize\tUsed\tAvail\tUse%%\tMounted on\n'
            fi
            cat
        } | column -t -s $'\t'
    fi
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            print_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -V|--version)
            print_version
            exit 0
            ;;
        -p|--pattern)
            if [[ -n "${2-}" ]]; then
                DISK_PATTERN="$2"
                shift 2
            else
                echo "Error: --pattern requires a value." >&2
                exit 1
            fi
            ;;
        -e|--exclude)
            if [[ -n "${2-}" ]]; then
                EXCLUDE_PATTERN="$2"
                shift 2
            else
                echo "Error: --exclude requires a value." >&2
                exit 1
            fi
            ;;
        -t|--type)
            if [[ -n "${2-}" ]]; then
                FILESYSTEM_TYPE="$2"
                shift 2
            else
                echo "Error: --type requires a value." >&2
                exit 1
            fi
            ;;
        -a|--all)
            INCLUDE_ALL=true
            shift
            ;;
        -s|--sort)
            if [[ -n "${2-}" ]]; then
                SORT_FIELD="$2"
                shift 2
            else
                echo "Error: --sort requires a field." >&2
                exit 1
            fi
            ;;
        -r|--reverse)
            REVERSE_SORT=true
            shift
            ;;
        -o|--output)
            if [[ -n "${2-}" ]]; then
                OUTPUT_FILE="$2"
                shift 2
            else
                echo "Error: --output requires a file path." >&2
                exit 1
            fi
            ;;
        --json)
            OUTPUT_JSON=true
            shift
            ;;
        --csv)
            OUTPUT_CSV=true
            shift
            ;;
        --no-header)
            NO_HEADER=true
            shift
            ;;
        -l|--log-file)
            if [[ -n "${2-}" ]]; then
                LOG_FILE="$2"
                LOG_ENABLED=true
                shift 2
            else
                echo "Error: --log-file requires a file path." >&2
                exit 1
            fi
            ;;
        *)
            echo "Unknown option: $1" >&2
            print_usage >&2
            exit 1
            ;;
    esac
done

case "$SORT_FIELD" in
    ""|filesystem|size|used|avail|use%|mount) ;;
    *)
        echo "Invalid sort field: $SORT_FIELD" >&2
        exit 1
        ;;
esac

if [[ "$OUTPUT_JSON" != true && "$OUTPUT_CSV" != true ]] && ! command -v column >/dev/null 2>&1; then
    echo "Error: 'column' is required for table output (or use --csv / --json)." >&2
    exit 1
fi

# Execute the main function, saving the output to a file if specified
if [[ -n "$OUTPUT_FILE" ]]; then
    list_disks | tee "$OUTPUT_FILE"
else
    list_disks
fi

# Log the action
log_action "Disk usage information displayed."

