#!/usr/bin/env bash

# Script Name: ram_memory.sh
# Description: Checks if the amount of RAM is enough to run the program.
# Usage: ram_memory.sh
# Example: ./ram_memory.sh

# Initialize the constants
MINIMUM=100000000
MIN_READABLE=$(echo "scale=2; $MINIMUM/1024/1024" | bc -l)

main() {

    ram="$(free | awk '/^Mem:/{print $2}')"
    if [ "$ram" -lt "$MINIMUM" ]; then
        echo "The system doesn't meet the requirements. RAM size must be at least $MIN_READABLE GB."
        exit 1
    fi

}

main "$@"

