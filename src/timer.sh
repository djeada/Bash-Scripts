#!/bin/bash

# Script Name: timer.sh
# Description: This script functions as a simple timer, displaying elapsed time in HH:MM:SS format.
#              It updates the time display every second on a single line in the terminal.
# Usage: ./timer.sh
# Example: ./timer.sh

secs=0
mins=0
hours=0

while true; do
    ((++secs))
    mins=$((secs / 60))
    hours=$((mins / 60))

    # Format and display the time in HH:MM:SS format, updating on the same line
    printf "\r%02d:%02d:%02d" $((hours % 24)) $((mins % 60)) $((secs % 60))

    # Wait for one second before the next update
    sleep 1
done
