#!/usr/bin/env bash

# Script Name: cpu_temp.sh
# Description: Displays the current CPU temperature.
# Usage: ./cpu_temp.sh
# Example: ./cpu_temp.sh

# Function to get the CPU temperature on Linux
get_linux_cpu_temp() {
    local temp_paths=(
        "/sys/class/thermal/thermal_zone0/temp"       # Common thermal zone
        "/sys/class/hwmon/hwmon*/temp1_input"         # HW Monitor
        "/sys/devices/virtual/thermal/thermal_zone*/temp" # Virtual devices
    )

    local path temp
    for potential in "${temp_paths[@]}"; do
        # Use the first accessible and readable file
        for file in "$potential"/*; do
            if [ -r "$file" ]; then
                path="$file"
                break 2
            fi
        done
    done

    if [ -z "$path" ]; then
        echo "Could not find a valid temperature file in common paths."
        exit 1
    fi

    temp=$(cat "$path")
    temp=$((temp/1000))

    echo "CPU temp: $temp C"
}

# Function to get the CPU temperature on MacOS
get_macos_cpu_temp() {
    osascript -e 'tell app "System Events" to tell process "SystemUIServer" to tell (menu bar item 2 of menu bar 1 where description is "systemUIServer") to value' | cut -d " " -f6 | sed 's/.$//g'
}

main() {
    case $(uname -s) in
        Linux*)   get_linux_cpu_temp "$@" ;;
        Darwin*)  get_macos_cpu_temp ;;
        *)        echo "Unsupported OS. This script works on Linux and MacOS only." && exit 1 ;;
    esac
}

main "$@"

