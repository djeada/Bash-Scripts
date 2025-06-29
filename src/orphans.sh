#!/usr/bin/env bash
set -euo pipefail

# Script Name: orphans.sh
# Description: This script displays processes that might be orphans,
#              i.e. processes whose parent process is not running.
# Usage: chmod +x orphans.sh && ./orphans.sh
# Example: ./orphans.sh  displays a list of processes that might be orphans.

# Create temporary files for process data.
TMP_FILE=$(mktemp /tmp/processes.XXXXXX)
PIDS_TMP_FILE=$(mktemp /tmp/pids.XXXXXX)

# Cleanup function to remove temporary files.
cleanup() {
    rm -f "$TMP_FILE" "$PIDS_TMP_FILE"
}

# Error handling function.
error_exit() {
    echo "$1" >&2
    cleanup
    exit 1
}

# Function to check for orphan processes.
check_orphans() {
    # Get a list of all processes' PPID and PID (without the header).
    ps -eo ppid,pid --no-headers > "$TMP_FILE"

    # Create a list of all running process IDs (PIDs) from the second column.
    awk '{print $2}' "$TMP_FILE" | sort -u > "$PIDS_TMP_FILE"

    # Check if each process has a parent process running.
    while read -r ppid pid; do
        # Skip kernel or system processes with parent PID 0.
        if [ "$ppid" -eq 0 ]; then
            continue
        fi

        # If the parent's PID is not in the list of running PIDs,
        # then the process might be orphaned.
        if ! grep -q -w "^$ppid$" "$PIDS_TMP_FILE"; then
            echo "Process $pid might be an orphan (parent PID: $ppid not found)"
        fi
    done < "$TMP_FILE"
}

# Ensure that temporary files were created.
if [[ ! -e "$TMP_FILE" || ! -e "$PIDS_TMP_FILE" ]]; then
    error_exit "Failed to create temporary file. Make sure you have the right permissions."
fi

# Set a trap to cleanup temporary files on exit.
trap cleanup EXIT

# Run the orphan-check function.
check_orphans

