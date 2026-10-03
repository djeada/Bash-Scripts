#!/usr/bin/env bash

# Script Name: ram_memory.sh
# Description: Checks if the system has enough RAM and displays current RAM usage by top programs.
# Usage: ram_memory.sh [options]
#
# Options:
#   -h, --help                Display this help message and exit.
#   -v, --verbose             Enable verbose output.
#   -m, --minimum RAM         Specify minimum RAM required (in UNIT). Default is 1.
#   -u, --unit UNIT           Specify unit for RAM values (GB, MB, KB). Default is GB.
#   -t, --top N               Display top N processes by RAM usage. Default is 10.
#   -l, --log-file FILE       Enable logging to specified log file.
#   -c, --critical PERCENT    Specify critical RAM usage level in percent (e.g., 90).
#   -s, --swap                Include swap memory in calculations.
#   -o, --output FILE         Save output to specified file.
#       --json                Output only a JSON summary (no table).
#       --no-color            Accepted for compatibility (output is never colored).
#
# Exit status: 0 if the minimum is met, 1 if not (or on error).
#
# Examples:
#   ram_memory.sh --minimum 2 --unit GB --top 5
#   ram_memory.sh -v -m 1024 -u MB
#   ram_memory.sh --critical 85

set -euo pipefail
export LC_ALL=C  # Use "." as the decimal separator in awk output.

# Default configurations
VERBOSE=false
MINIMUM_RAM=1
UNIT="GB"
TOP_N=10
LOG_FILE=""
CRITICAL_LEVEL=0
INCLUDE_SWAP=false
OUTPUT_FILE=""
OUTPUT_JSON=false

# Function to display usage information
print_usage() {
    cat << EOF
Usage: $0 [options]

Options:
  -h, --help                Display this help message and exit.
  -v, --verbose             Enable verbose output.
  -m, --minimum RAM         Specify minimum RAM required (in UNIT). Default is 1.
  -u, --unit UNIT           Specify unit for RAM values (GB, MB, KB). Default is GB.
  -t, --top N               Display top N processes by RAM usage. Default is 10.
  -l, --log-file FILE       Enable logging to specified log file.
  -c, --critical PERCENT    Specify critical RAM usage level in percent (e.g., 90).
  -s, --swap                Include swap memory in calculations.
  -o, --output FILE         Save output to specified file.
      --json                Output only a JSON summary (no table).
      --no-color            Accepted for compatibility (output is never colored).

Exit status: 0 if the minimum is met, 1 if not (or on error).

Examples:
  $0 --minimum 2 --unit GB --top 5
  $0 -v -m 1024 -u MB
  $0 --critical 85

EOF
}

die() {
    echo "Error: $*" >&2
    exit 1
}

# Function for logging
log_action() {
    local message="$1"
    if [[ -n "$LOG_FILE" ]]; then
        echo "$(date +"%Y-%m-%d %T"): $message" >> "$LOG_FILE"
    fi
    if [[ "$VERBOSE" == true ]]; then
        echo "$message" >&2
    fi
}

# Print the value (in kB) of a /proc/meminfo field, or 0 if absent.
meminfo_kb() {
    awk -v key="$1:" '$1 == key { print $2; found = 1 } END { if (!found) print 0 }' /proc/meminfo
}

# Convert a kB value to $UNIT with two decimals.
convert_ram() {
    local ram_kb="$1"
    case "$UNIT" in
        GB) awk -v kb="$ram_kb" 'BEGIN { printf "%.2f\n", kb / 1024 / 1024 }' ;;
        MB) awk -v kb="$ram_kb" 'BEGIN { printf "%.2f\n", kb / 1024 }' ;;
        KB) echo "$ram_kb" ;;
    esac
}

# Convert $MINIMUM_RAM (in $UNIT) to an integer number of kB.
minimum_in_kb() {
    local factor=1
    case "$UNIT" in
        GB) factor=1048576 ;;
        MB) factor=1024 ;;
    esac
    awk -v m="$MINIMUM_RAM" -v f="$factor" 'BEGIN { printf "%d\n", m * f }'
}

# Ensure an option has a value.
require_value() {
    [[ -n "${2:-}" ]] || die "$1 requires a value."
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            print_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -m|--minimum)
            require_value "$1" "${2:-}"
            MINIMUM_RAM="$2"
            shift 2
            ;;
        -u|--unit)
            require_value "$1" "${2:-}"
            UNIT="${2^^}"
            shift 2
            ;;
        -t|--top)
            require_value "$1" "${2:-}"
            TOP_N="$2"
            shift 2
            ;;
        -l|--log-file)
            require_value "$1" "${2:-}"
            LOG_FILE="$2"
            shift 2
            ;;
        -c|--critical)
            require_value "$1" "${2:-}"
            CRITICAL_LEVEL="$2"
            shift 2
            ;;
        -s|--swap)
            INCLUDE_SWAP=true
            shift
            ;;
        -o|--output)
            require_value "$1" "${2:-}"
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --json)
            OUTPUT_JSON=true
            shift
            ;;
        --no-color)
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            print_usage >&2
            exit 1
            ;;
    esac
done

# Validate options
case "$UNIT" in
    GB|MB|KB) ;;
    *) die "Invalid unit: $UNIT (expected GB, MB or KB)." ;;
esac
[[ "$MINIMUM_RAM" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "--minimum must be a non-negative number."
[[ "$TOP_N" =~ ^[0-9]+$ ]] || die "--top must be a non-negative integer."
[[ "$CRITICAL_LEVEL" =~ ^[0-9]+$ ]] || die "--critical must be an integer percentage."
[[ -r /proc/meminfo ]] || die "/proc/meminfo is not readable (this script requires Linux)."

# Redirect output to file if specified
if [[ -n "$OUTPUT_FILE" ]]; then
    exec > >(tee -a "$OUTPUT_FILE")
fi

# Gather memory information
total_ram_kb=$(meminfo_kb MemTotal)
mem_free_kb=$(meminfo_kb MemFree)
mem_available_kb=$(meminfo_kb MemAvailable)
swap_total_kb=$(meminfo_kb SwapTotal)
swap_free_kb=$(meminfo_kb SwapFree)
(( total_ram_kb > 0 )) || die "Unable to determine total RAM."

checked_kb=$total_ram_kb
if [[ "$INCLUDE_SWAP" == true ]]; then
    checked_kb=$((checked_kb + swap_total_kb))
fi
checked_ram=$(convert_ram "$checked_kb")
min_ram_kb=$(minimum_in_kb)

meets_minimum=true
if (( checked_kb < min_ram_kb )); then
    meets_minimum=false
    log_action "Insufficient RAM. Required: $MINIMUM_RAM $UNIT, Available: $checked_ram $UNIT."
else
    log_action "Sufficient RAM. Required: $MINIMUM_RAM $UNIT, Available: $checked_ram $UNIT."
fi

mem_used_percent=$(((total_ram_kb - mem_available_kb) * 100 / total_ram_kb))
critical=false
if (( CRITICAL_LEVEL > 0 && mem_used_percent > CRITICAL_LEVEL )); then
    critical=true
    log_action "Memory usage critical: $mem_used_percent% used."
fi

if [[ "$OUTPUT_JSON" == true ]]; then
    cat << EOF
{
    "unit": "$UNIT",
    "total_ram": $(convert_ram "$total_ram_kb"),
    "mem_free": $(convert_ram "$mem_free_kb"),
    "mem_available": $(convert_ram "$mem_available_kb"),
    "swap_total": $(convert_ram "$swap_total_kb"),
    "swap_free": $(convert_ram "$swap_free_kb"),
    "minimum_required": $MINIMUM_RAM,
    "meets_minimum": $meets_minimum,
    "mem_used_percent": $mem_used_percent,
    "critical": $critical
}
EOF
else
    if [[ "$meets_minimum" == true ]]; then
        echo "The system meets the minimum RAM requirements."
    else
        echo "The system doesn't meet the requirements. RAM size must be at least $MINIMUM_RAM $UNIT." >&2
    fi

    if (( TOP_N > 0 )); then
        echo "Top $TOP_N programs by RAM usage:"
        # awk reads all of ps's output, so ps never gets SIGPIPE under pipefail.
        ps aux --sort=-%mem | awk -v n="$TOP_N" 'NR <= n + 1 { printf "%-10s %-8s %-5s %-5s %s\n", $1, $2, $3, $4, $11 }'
        log_action "Top RAM consuming processes displayed."
    fi

    if [[ "$critical" == true ]]; then
        echo "Warning: Memory usage is above critical level ($CRITICAL_LEVEL%): $mem_used_percent% used." >&2
    fi
fi

[[ "$meets_minimum" == true ]]

