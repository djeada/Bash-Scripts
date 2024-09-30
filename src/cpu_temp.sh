#!/usr/bin/env bash

# Script Name: cpu_temp.sh
# Description: Displays the current CPU temperature with advanced options.
# Usage: cpu_temp.sh [options]
#
# Options:
#   -h, --help              Display this help message and exit.
#   -v, --verbose           Enable verbose output.
#   -u, --unit UNIT         Specify temperature unit: C (Celsius), F (Fahrenheit), K (Kelvin). Default is C.
#   -j, --json              Output in JSON format.
#   -l, --log-file FILE     Log output to specified file.
#   -m, --monitor INTERVAL  Monitor CPU temperature at specified interval in seconds.
#   -o, --output FILE       Save output to specified file.
#   -V, --version           Display script version and exit.
#
# Examples:
#   cpu_temp.sh --unit F
#   cpu_temp.sh -v -m 5
#   cpu_temp.sh --json --output cpu_temp.json

set -euo pipefail

VERSION="1.0.0"

# Default configurations
VERBOSE=false
UNIT="C"
OUTPUT_JSON=false
LOG_FILE=""
LOG_ENABLED=false
MONITOR_INTERVAL=0
OUTPUT_FILE=""

# Function to display usage information
print_usage() {
    cat << EOF
Usage: $0 [options]

Options:
  -h, --help              Display this help message and exit.
  -v, --verbose           Enable verbose output.
  -u, --unit UNIT         Specify temperature unit: C (Celsius), F (Fahrenheit), K (Kelvin). Default is C.
  -j, --json              Output in JSON format.
  -l, --log-file FILE     Log output to specified file.
  -m, --monitor INTERVAL  Monitor CPU temperature at specified interval in seconds.
  -o, --output FILE       Save output to specified file.
  -V, --version           Display script version and exit.

Examples:
  $0 --unit F
  $0 -v -m 5
  $0 --json --output cpu_temp.json
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

# Function to convert temperature units
convert_temp() {
    local temp_c="$1"
    local unit="$2"
    local temp_output

    case "$unit" in
        C|c)
            temp_output="$temp_c"
            ;;
        F|f)
            temp_output=$(echo "scale=2; ($temp_c * 9/5) + 32" | bc)
            ;;
        K|k)
            temp_output=$(echo "scale=2; $temp_c + 273.15" | bc)
            ;;
        *)
            echo "Invalid unit: $unit"
            exit 1
            ;;
    esac

    echo "$temp_output"
}

# Function to get the CPU temperature on Linux
get_linux_cpu_temp() {
    local temp_paths=(
        "/sys/class/thermal/thermal_zone*/temp"
        "/sys/class/hwmon/hwmon*/temp1_input"
    )

    for path in "${temp_paths[@]}"; do
        for file in $path; do
            if [[ -r "$file" ]]; then
                local temp_raw
                temp_raw=$(cat "$file")
                if [[ "$temp_raw" -gt 1000 ]]; then
                    temp_c=$(echo "scale=2; $temp_raw / 1000" | bc)
                else
                    temp_c="$temp_raw"
                fi
                local temp
                temp=$(convert_temp "$temp_c" "$UNIT")
                echo "$temp"
                return
            fi
        done
    done

    echo "Could not find a valid temperature file in common paths." >&2
    exit 1
}

# Function to get the CPU temperature on macOS
get_macos_cpu_temp() {
    if ! command -v osx-cpu-temp &> /dev/null; then
        echo "Error: 'osx-cpu-temp' utility is not installed. Please install it from https://github.com/lavoiesl/osx-cpu-temp" >&2
        exit 1
    fi

    local temp_c
    temp_c=$(osx-cpu-temp -C | grep -o '[0-9]*\.[0-9]*')
    if [[ -z "$temp_c" ]]; then
        echo "Could not retrieve CPU temperature. Ensure you have the necessary permissions." >&2
        exit 1
    fi
    local temp
    temp=$(convert_temp "$temp_c" "$UNIT")
    echo "$temp"
}

# Function to get the CPU temperature on FreeBSD
get_freebsd_cpu_temp() {
    if sysctl hw.acpi.thermal.tz0.temperature >/dev/null 2>&1; then
        local temp_str
        temp_str=$(sysctl hw.acpi.thermal.tz0.temperature | awk '{print $2}')
        local temp_c=${temp_str%.*}
        local temp
        temp=$(convert_temp "$temp_c" "$UNIT")
        echo "$temp"
    else
        echo "Could not retrieve CPU temperature on FreeBSD." >&2
        exit 1
    fi
}

# Main function to get CPU temperature
get_cpu_temp() {
    local temp
    case "$(uname -s)" in
        Linux*)
            temp=$(get_linux_cpu_temp)
            ;;
        Darwin*)
            temp=$(get_macos_cpu_temp)
            ;;
        FreeBSD*)
            temp=$(get_freebsd_cpu_temp)
            ;;
        *)
            echo "Unsupported OS. This script works on Linux, macOS, and FreeBSD only." >&2
            exit 1
            ;;
    esac
    echo "$temp"
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
        -u|--unit)
            if [[ -n "${2-}" ]]; then
                UNIT="$2"
                shift 2
            else
                echo "Error: --unit requires a value."
                exit 1
            fi
            ;;
        -j|--json)
            OUTPUT_JSON=true
            shift
            ;;
        -l|--log-file)
            if [[ -n "${2-}" ]]; then
                LOG_FILE="$2"
                LOG_ENABLED=true
                shift 2
            else
                echo "Error: --log-file requires a value."
                exit 1
            fi
            ;;
        -m|--monitor)
            if [[ -n "${2-}" ]]; then
                MONITOR_INTERVAL="$2"
                shift 2
            else
                echo "Error: --monitor requires an interval in seconds."
                exit 1
            fi
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
        -V|--version)
            print_version
            exit 0
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

# Main execution function
main() {
    if [[ "$MONITOR_INTERVAL" -gt 0 ]]; then
        while true; do
            temp=$(get_cpu_temp)
            if [[ "$OUTPUT_JSON" == true ]]; then
                echo "{\"cpu_temperature\": \"$temp\", \"unit\": \"$UNIT\"}"
            else
                echo "CPU Temperature: $temp°$UNIT"
            fi
            log_action "CPU Temperature: $temp°$UNIT"
            sleep "$MONITOR_INTERVAL"
        done
    else
        temp=$(get_cpu_temp)
        if [[ "$OUTPUT_JSON" == true ]]; then
            echo "{\"cpu_temperature\": \"$temp\", \"unit\": \"$UNIT\"}"
        else
            echo "CPU Temperature: $temp°$UNIT"
        fi
        log_action "CPU Temperature: $temp°$UNIT"
    fi
}

main
