#!/usr/bin/env bash

# Script Name: ram_memory.sh
# Description: Checks if the system has enough RAM and displays current RAM usage by top programs.
# Usage: ram_memory.sh [options]
#
# Options:
#   -h, --help                Display this help message and exit.
#   -v, --verbose             Enable verbose output.
#   -m, --minimum RAM         Specify minimum RAM required (in GB). Default is 1 GB.
#   -u, --unit UNIT           Specify unit for RAM values (GB, MB, KB). Default is GB.
#   -t, --top N               Display top N processes by RAM usage. Default is 10.
#   -l, --log-file FILE       Enable logging to specified log file.
#   -c, --critical PERCENT    Specify critical RAM usage level in percent (e.g., 90).
#   -s, --swap                Include swap memory in calculations.
#   -o, --output FILE         Save output to specified file.
#       --json                Output in JSON format.
#       --no-color            Disable colored output.
#
# Examples:
#   ram_memory.sh --minimum 2 --unit GB --top 5
#   ram_memory.sh -v -m 1024 -u MB
#   ram_memory.sh --critical 85

set -euo pipefail

# Default configurations
VERBOSE=false
MINIMUM_RAM=1
UNIT="GB"
TOP_N=10
LOG_FILE=""
LOG_ENABLED=false
CRITICAL_LEVEL=0
INCLUDE_SWAP=false
OUTPUT_FILE=""
OUTPUT_JSON=false
NO_COLOR=false

# Function to display usage information
print_usage() {
    cat << EOF
Usage: $0 [options]

Options:
  -h, --help                Display this help message and exit.
  -v, --verbose             Enable verbose output.
  -m, --minimum RAM         Specify minimum RAM required (in GB). Default is 1 GB.
  -u, --unit UNIT           Specify unit for RAM values (GB, MB, KB). Default is GB.
  -t, --top N               Display top N processes by RAM usage. Default is 10.
  -l, --log-file FILE       Enable logging to specified log file.
  -c, --critical PERCENT    Specify critical RAM usage level in percent (e.g., 90).
  -s, --swap                Include swap memory in calculations.
  -o, --output FILE         Save output to specified file.
      --json                Output in JSON format.
      --no-color            Disable colored output.

Examples:
  $0 --minimum 2 --unit GB --top 5
  $0 -v -m 1024 -u MB
  $0 --critical 85

EOF
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

# Function to convert RAM values
convert_ram() {
    local ram_kb="$1"
    local unit="$2"
    local ram_value

    case "$unit" in
        GB|gb)
            ram_value=$(echo "scale=2; $ram_kb/1024/1024" | bc)
            ;;
        MB|mb)
            ram_value=$(echo "scale=2; $ram_kb/1024" | bc)
            ;;
        KB|kb)
            ram_value="$ram_kb"
            ;;
        *)
            echo "Invalid unit: $unit"
            exit 1
            ;;
    esac
    echo "$ram_value"
}

# Function to check minimum RAM
check_minimum_ram() {
    local total_ram_kb
    if ! total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}'); then
        echo "Unable to determine total RAM."
        exit 1
    fi

    if [[ "$INCLUDE_SWAP" == true ]]; then
        if swap_total_kb=$(grep SwapTotal /proc/meminfo | awk '{print $2}'); then
            total_ram_kb=$((total_ram_kb + swap_total_kb))
        fi
    fi

    local total_ram=$(convert_ram "$total_ram_kb" "$UNIT")
    local min_ram_kb
    case "$UNIT" in
        GB|gb)
            min_ram_kb=$(echo "$MINIMUM_RAM * 1024 * 1024" | bc)
            ;;
        MB|mb)
            min_ram_kb=$(echo "$MINIMUM_RAM * 1024" | bc)
            ;;
        KB|kb)
            min_ram_kb="$MINIMUM_RAM"
            ;;
    esac

    if (( total_ram_kb < min_ram_kb )); then
        echo "The system doesn't meet the requirements. RAM size must be at least $MINIMUM_RAM $UNIT."
        log_action "Insufficient RAM. Required: $MINIMUM_RAM $UNIT, Available: $total_ram $UNIT."
        exit 1
    else
        echo "The system meets the minimum RAM requirements."
        log_action "Sufficient RAM. Required: $MINIMUM_RAM $UNIT, Available: $total_ram $UNIT."
    fi
}

# Function to display top RAM usage
display_top_ram_usage() {
    echo "Top $TOP_N programs by RAM usage:"
    ps aux --sort=-%mem | head -n $((TOP_N + 1)) | awk '{printf "%-10s %-8s %-5s %-5s %s\n", $1, $2, $3, $4, $11}' | column -t
    log_action "Top RAM consuming processes displayed."
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
        -m|--minimum)
            if [[ -n "$2" ]]; then
                MINIMUM_RAM="$2"
                shift 2
            else
                echo "Error: --minimum requires a value."
                exit 1
            fi
            ;;
        -u|--unit)
            if [[ -n "$2" ]]; then
                UNIT="$2"
                shift 2
            else
                echo "Error: --unit requires a value."
                exit 1
            fi
            ;;
        -t|--top)
            if [[ -n "$2" ]]; then
                TOP_N="$2"
                shift 2
            else
                echo "Error: --top requires a value."
                exit 1
            fi
            ;;
        -l|--log-file)
            if [[ -n "$2" ]]; then
                LOG_FILE="$2"
                LOG_ENABLED=true
                shift 2
            else
                echo "Error: --log-file requires a value."
                exit 1
            fi
            ;;
        -c|--critical)
            if [[ -n "$2" ]]; then
                CRITICAL_LEVEL="$2"
                shift 2
            else
                echo "Error: --critical requires a value."
                exit 1
            fi
            ;;
        -s|--swap)
            INCLUDE_SWAP=true
            shift
            ;;
        -o|--output)
            if [[ -n "$2" ]]; then
                OUTPUT_FILE="$2"
                shift 2
            else
                echo "Error: --output requires a value."
                exit 1
            fi
            ;;
        --json)
            OUTPUT_JSON=true
            shift
            ;;
        --no-color)
            NO_COLOR=true
            shift
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

# Main execution
check_minimum_ram
display_top_ram_usage

# Check critical RAM usage level
if [[ "$CRITICAL_LEVEL" -gt 0 ]]; then
    meminfo=$(grep -E 'MemTotal|MemAvailable' /proc/meminfo)
    total_ram_kb=$(echo "$meminfo" | grep MemTotal | awk '{print $2}')
    mem_available_kb=$(echo "$meminfo" | grep MemAvailable | awk '{print $2}')
    mem_used_kb=$((total_ram_kb - mem_available_kb))
    mem_used_percent=$((mem_used_kb * 100 / total_ram_kb))

    if (( mem_used_percent > CRITICAL_LEVEL )); then
        echo "Warning: Memory usage is above critical level ($CRITICAL_LEVEL%)."
        log_action "Memory usage critical: $mem_used_percent% used."
    fi
fi

# Output in JSON format if requested
if [[ "$OUTPUT_JSON" == true ]]; then
    meminfo=$(grep -E 'MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree' /proc/meminfo)
    total_ram_kb=$(echo "$meminfo" | grep MemTotal | awk '{print $2}')
    mem_free_kb=$(echo "$meminfo" | grep MemFree | awk '{print $2}')
    mem_available_kb=$(echo "$meminfo" | grep MemAvailable | awk '{print $2}')
    swap_total_kb=$(echo "$meminfo" | grep SwapTotal | awk '{print $2}')
    swap_free_kb=$(echo "$meminfo" | grep SwapFree | awk '{print $2}')
    total_ram=$(convert_ram "$total_ram_kb" "$UNIT")
    mem_free=$(convert_ram "$mem_free_kb" "$UNIT")
    mem_available=$(convert_ram "$mem_available_kb" "$UNIT")
    swap_total=$(convert_ram "$swap_total_kb" "$UNIT")
    swap_free=$(convert_ram "$swap_free_kb" "$UNIT")

    cat << EOF
{
    "total_ram_$UNIT": "$total_ram",
    "mem_free_$UNIT": "$mem_free",
    "mem_available_$UNIT": "$mem_available",
    "swap_total_$UNIT": "$swap_total",
    "swap_free_$UNIT": "$swap_free"
}
EOF
fi
