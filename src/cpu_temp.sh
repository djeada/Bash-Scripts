#!/usr/bin/env bash

# Script Name: cpu_temp.sh
# Description: Displays the current CPU temperature.
# Usage: ./cpu_temp.sh
# Example: ./cpu_temp.sh

# Function to get the CPU temperature on Linux
get_linux_cpu_temp() {
    local temp_paths=(
        "/sys/class/thermal/thermal_zone0/temp"
        "/sys/class/hwmon/hwmon*/temp1_input"
        "/sys/devices/virtual/thermal/thermal_zone*/temp"
    )

    for path in "${temp_paths[@]}"; do
        for file in $path; do
            if [ -r "$file" ]; then
                local temp=$(cat "$file")
                temp=$((temp/1000))
                echo "CPU temp: $temp°C"
                return
            fi
        done
    done

    echo "Could not find a valid temperature file in common paths."
    exit 1
}

# Function to get the CPU temperature on MacOS
get_macos_cpu_temp() {
    if ! command -v osascript &> /dev/null; then
        echo "Error: Required command 'osascript' not found" >&2
        exit 1
    fi

    local temp
    temp=$(osascript -e 'tell application "System Events" to get CPU temperature of sensor 1' || echo "Error")
    
    if [[ $temp == "Error" ]]; then
        echo "Could not retrieve CPU temperature. Ensure you have the necessary permissions."
        exit 1
    fi

    echo "CPU temp: $temp°C"
}

main() {
    case $(uname -s) in
        Linux*)   get_linux_cpu_temp "$@" ;;
        Darwin*)  get_macos_cpu_temp ;;
        *)        echo "Unsupported OS. This script works on Linux and MacOS only." && exit 1 ;;
    esac
}

main "$@"
