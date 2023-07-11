#!/usr/bin/env bash

# Script Name: ram_memory.sh
# Description: Checks if the amount of RAM is enough to run the program and shows the current RAM usage by top 10 programs.
# Usage: ./ram_memory.sh
# Example: ./ram_memory.sh

# Initialize the constants
MINIMUM_RAM_KB=100000000
MINIMUM_RAM_GB=$(echo "scale=2; $MINIMUM_RAM_KB/1024/1024" | bc -l)

# Function to check if the system has the minimum required RAM
check_minimum_ram() {
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    if (( total_ram_kb < MINIMUM_RAM_KB )); then
        echo "The system doesn't meet the requirements. RAM size must be at least $MINIMUM_RAM_GB GB."
        exit 1
    else
        echo "The system meets the minimum RAM requirements."
    fi
}

# Function to display the top 10 programs by RAM usage
display_top_ram_usage() {
    echo "Top 10 programs by RAM usage:"
    ps aux --sort=-%mem | awk 'NR<=11 {print $0}'
}

main() {
    check_minimum_ram
    display_top_ram_usage
}

main
