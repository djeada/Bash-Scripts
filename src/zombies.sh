#!/usr/bin/env bash

# Script Name: zombies.sh
# Description: This script displays zombie processes, i.e., processes that have terminated but have not been fully removed from the system.
# Usage: ./zombies.sh
# Example: ./zombies.sh displays a list of zombie processes.

# Define temporary file
TMP_FILE=$(mktemp /tmp/processes.XXXXXX)

# Cleanup function
cleanup() {
    rm -f "$TMP_FILE"
}

# Error handling function
error_exit() {
    echo "$1" 1>&2
    cleanup
    exit 1
}

# Function to check for zombie processes
check_zombies() {
    # Get a list of all processes and their status
    ps -eo pid,stat | awk 'NR>1 && $2 ~ /^Z/ {print $1 " " $2}' > "$TMP_FILE"

    # Check if each process is a zombie
    while read -r pid stat; do
        echo "Process $pid is a zombie"
    done < "$TMP_FILE"
}

# Check if the temp file was created
if [[ ! -e "$TMP_FILE" ]]; then
    error_exit "Failed to create temporary file. Make sure you have the right permissions."
fi

# Set a trap for cleanup on script exit
trap cleanup EXIT

# Run the main function
check_zombies
