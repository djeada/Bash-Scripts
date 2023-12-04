#!/usr/bin/env bash

# Script Name: ram_memory.sh
# Description: Checks if the amount of RAM is enough to run the program and shows the current RAM usage by top 10 programs.
# Usage: ./ram_memory.sh [minimum RAM in GB]
# Example: ./ram_memory.sh 2

LOG_FILE="/var/log/ram_memory.log"
LOG_ENABLED=0

# Command-line argument for minimum RAM, default is 100 GB (converted to KB)
MINIMUM_RAM_KB=${1:-100000000}
MINIMUM_RAM_GB=$(echo "scale=2; $MINIMUM_RAM_KB/1024/1024" | bc -l)

function log_action {
    [ $LOG_ENABLED -eq 1 ] && echo "$(date +"%Y-%m-%d %T"): $1" >> $LOG_FILE
}

function check_minimum_ram {
    if ! total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}'); then
        echo "Unable to determine total RAM."
        exit 1
    fi

    if (( total_ram_kb < MINIMUM_RAM_KB )); then
        echo "The system doesn't meet the requirements. RAM size must be at least $MINIMUM_RAM_GB GB."
        log_action "Insufficient RAM. Required: $MINIMUM_RAM_GB GB, Available: $(echo "scale=2; $total_ram_kb/1024/1024" | bc -l) GB."
        exit 1
    else
        echo "The system meets the minimum RAM requirements."
        log_action "Sufficient RAM. Required: $MINIMUM_RAM_GB GB, Available: $(echo "scale=2; $total_ram_kb/1024/1024" | bc -l) GB."
    fi
}

function display_top_ram_usage {
    echo "Top 10 programs by RAM usage:"
    ps aux --sort=-%mem | awk 'NR<=11 {print $1, $2, $3, $4, $11}' | column -t
    log_action "Top RAM consuming processes displayed."
}

while getopts "l" opt; do
    case $opt in
        l)
            LOG_ENABLED=1
            ;;
        *)
            echo "Invalid option: $1"
            exit 1
            ;;
    esac
done

check_minimum_ram
display_top_ram_usage
