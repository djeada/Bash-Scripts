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
#   -o, --output FILE         Save output to specified file.
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
  -o, --output FILE         Save output to specified file.
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

# Function to list disk partitions and usage
list_disks() {
    local df_options="-h"
    if [[ "$INCLUDE_ALL" == true ]]; then
        df_options="$df_options -a"
    fi

    local df_output
    df_output=$(df $df_options)

    # Exclude unwanted filesystems
    local awk_script='NR>1'
    if [[ "$INCLUDE_ALL" == false ]]; then
        awk_script="$awk_script && \$1 !~ /^tmpfs/ && \$1 !~ /^udev/ && \$1 !~ /^devtmpfs/"
    fi
    if [[ -n "$FILESYSTEM_TYPE" ]]; then
        awk_script="$awk_script && \$1 ~ /$FILESYSTEM_TYPE/"
    fi
    if [[ -n "$DISK_PATTERN" ]]; then
        awk_script="$awk_script && \$1 ~ /$DISK_PATTERN/"
    fi
    if [[ -n "$EXCLUDE_PATTERN" ]]; then
        awk_script="$awk_script && \$1 !~ /$EXCLUDE_PATTERN/"
    fi

    # Prepare sort options
    local sort_options=""
    if [[ -n "$SORT_FIELD" ]]; then
        local field_number
        case "$SORT_FIELD" in
            filesystem) field_number=1 ;;
            size)       field_number=2 ;;
            used)       field_number=3 ;;
            avail)      field_number=4 ;;
            use%)       field_number=5 ;;
            mount)      field_number=6 ;;
            *)
                echo "Invalid sort field: $SORT_FIELD"
                exit 1
                ;;
        esac
        sort_options="-k${field_number}"
    fi
    if [[ "$REVERSE_SORT" == true ]]; then
        sort_options="$sort_options -r"
    fi

    # Output formatting
    local output_format
    if [[ "$OUTPUT_JSON" == true ]]; then
        output_format="json"
    elif [[ "$OUTPUT_CSV" == true ]]; then
        output_format="csv"
    else
        output_format="plain"
    fi

    # Process and output the data
    echo "$df_output" | awk "$awk_script" | \
    {
        if [[ "$output_format" == "json" ]]; then
            awk 'BEGIN { ORS=""; print "[" }
                 {
                     if (NR > 1) print ","
                     printf "{ \"filesystem\": \"%s\", \"size\": \"%s\", \"used\": \"%s\", \"avail\": \"%s\", \"use%%\": \"%s\", \"mount\": \"%s\" }", $1, $2, $3, $4, $5, $6
                 }
                 END { print "]" }'
        elif [[ "$output_format" == "csv" ]]; then
            if [[ "$NO_HEADER" == false ]]; then
                echo "Filesystem,Size,Used,Avail,Use%,Mounted on"
            fi
            awk '{ printf "%s,%s,%s,%s,%s,%s\n", $1, $2, $3, $4, $5, $6 }'
        else
            if [[ "$NO_HEADER" == false ]]; then
                echo "Filesystem      Size  Used Avail Use% Mounted on"
            fi
            column -t
        fi
    } | sort $sort_options
}

# Parse command-line arguments
ARGS=("$@")
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
                echo "Error: --pattern requires a value."
                exit 1
            fi
            ;;
        -e|--exclude)
            if [[ -n "${2-}" ]]; then
                EXCLUDE_PATTERN="$2"
                shift 2
            else
                echo "Error: --exclude requires a value."
                exit 1
            fi
            ;;
        -t|--type)
            if [[ -n "${2-}" ]]; then
                FILESYSTEM_TYPE="$2"
                shift 2
            else
                echo "Error: --type requires a value."
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
                echo "Error: --sort requires a field."
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
                echo "Error: --output requires a file path."
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
                echo "Error: --log-file requires a file path."
                exit 1
            fi
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Redirect output to file if specified
if [[ -n "$OUTPUT_FILE" ]]; then
    exec > >(tee -a "$OUTPUT_FILE")
fi

# Execute the main function
list_disks

# Log the action
log_action "Disk usage information displayed."
