#!/usr/bin/env bash

# Script Name: orphans.sh
# Description: This script displays processes that might be orphans, i.e. processes that have no parent process.
# Usage: `orphans.sh`
# Example: `orphans.sh` displays a list of processes that might be orphans.

# Get a list of all processes
ps -eo ppid,pid,comm | sed 1d | awk '{print $1 " " $2}' > /tmp/processes.txt

# Check if each process has a parent process
while read -r line; do
  ppid=$(echo "$line" | awk '{print $1}')
  pid=$(echo "$line" | awk '{print $2}')
  if ! grep -q "$ppid" /tmp/processes.txt; then
    echo "Process $pid might be an orphan"
  fi
done < /tmp/processes.txt

# Remove the temporary file
rm /tmp/processes.txt
