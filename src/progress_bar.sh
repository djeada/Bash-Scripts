#!/usr/bin/env bash

# Script Name: progress_bar.sh
# Description: Displays a hacker-themed progress bar animation in the terminal.
# Usage: ./progress_bar.sh
# Example: ./progress_bar.sh

# Define colors ($'...' so they hold real escape characters, usable with printf %s)
GREEN=$'\033[0;32m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'  # No Color

clear 2>/dev/null  # Clear the terminal for a neat start

# Print fancy hacker-like messages
echo "${BLUE}Initializing covert protocol...${NC}"
sleep 0.3
echo "${BLUE}Accessing mainframe database...${NC}"
sleep 0.3
echo "${BLUE}Bypassing firewall...${NC}"
sleep 0.3
echo "${GREEN}Firewall bypassed successfully!${NC}"
sleep 0.3

# Get the width of the terminal (fall back to 80 columns), keeping room for the percentage
total_width=$(tput cols 2>/dev/null || echo 80)
(( total_width < 20 )) && total_width=20
max_bar=$((total_width - 10))

# Define function to draw the progress bar
draw_progress_bar() {
    local progress=$1  # integer from 0 to 100
    local bar_length=$((max_bar * progress / 100))
    local filled empty

    # Build strings of the right lengths ('%*s' pads with spaces)
    printf -v filled '%*s' "$bar_length" ''
    printf -v empty '%*s' "$((max_bar - bar_length))" ''

    printf "\r%s[%s%s] %3d%%%s" "$GREEN" "${filled// /=}" "$empty" "$progress" "$NC"
}

# This loop will mock data processing and draw the progress bar
for i in $(seq 1 100); do
    draw_progress_bar "$i"
    sleep 0.05  # Sleep for a short duration to simulate work
done

echo ""  # Newline for cleaner output
echo "${GREEN}Boss Level unlocked!${NC}"

