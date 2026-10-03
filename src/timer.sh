#!/usr/bin/env bash

# Script Name: timer.sh
# Description: This script functions as a simple timer, displaying elapsed time in HH:MM:SS format.
#              It updates the time display every second on a single line in the terminal.
#              Press Ctrl+C to stop.
# Usage: ./timer.sh
# Example: ./timer.sh

# Print a newline on Ctrl+C so the prompt doesn't overwrite the last time shown
trap 'echo; exit 0' INT

# SECONDS is a Bash builtin counting seconds since it was set, so the
# display doesn't drift even though each loop takes slightly over a second
SECONDS=0

while true; do
    secs=$SECONDS

    # Format and display the time in HH:MM:SS format, updating on the same line
    printf "\r%02d:%02d:%02d" $((secs / 3600)) $((secs / 60 % 60)) $((secs % 60))

    # Wait for one second before the next update
    sleep 1
done

