#!/usr/bin/env bash

# Script Name: zombies.sh
# Description: This script displays zombie processes, i.e. processes that have terminated but have not been fully removed from the system.
# Usage: `zombies.sh`
# Example: `zombies.sh` displays a list of zombie processes.

# Get a list of all processes and their status
ps -eo pid,stat | sed 1d | awk '{print $1 " " $2}' > /tmp/processes.txt

# Check if each process is a zombie
while read -r line; do
  pid=$(echo "$line" | awk '{print $1}')
  stat=$(echo "$line" | awk '{print $2}')
  if [[ "$stat" == Z* ]]; then
    echo "Process $pid is a zombie"
  fi
done < /tmp/processes.txt

# Remove the temporary file
rm /tmp/processes.txt
