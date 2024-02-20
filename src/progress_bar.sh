#!/bin/bash

# Define colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Color


clear  # Clear the terminal for a neat start

# Print fancy hacker-like messages
echo -e "${BLUE}Initializing covert protocol...${NC}"
sleep 0.3
echo -e "${BLUE}Accessing mainframe database...${NC}"
sleep 0.3
echo -e "${BLUE}Bypassing firewall...${NC}"
sleep 0.3
echo -e "${GREEN}Firewall bypassed successfully!${NC}"
sleep 0.3

# Define function to draw the progress bar
draw_progress_bar() {
    local progress total_width bar_length

    # Progress will be an integer (0 to 100)
    progress=$1
    total_width=$(tput cols)  # Get the width of the terminal

    # Deducting 10 to leave space for percentage
    let bar_length=($total_width-10)*$progress/100

    # Draw the progress bar
    printf "\r${GREEN}["
    printf "%0.s=" $(seq 1 $bar_length)
    printf "%0.s " $(seq 1 $(($total_width-$bar_length-10)))
    printf "] %3d%%${NC}" $progress
}

# This loop will mock data processing and draw the progress bar
for i in $(seq 1 100); do
    draw_progress_bar $i
    sleep 0.05  # Sleep for a short duration to simulate work
done

echo ""  # Newline for cleaner output
echo -e "${GREEN}Boss Level unlocked!${NC}"
