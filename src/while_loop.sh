#!/usr/bin/env bash

# Script Name: while_loop.sh
# Description: Demonstrates a while loop that prints a message every 10 seconds.
# Usage: ./while_loop.sh
# Example: ./while_loop.sh

echo "You are running this script at your own risk!"
echo "Press Ctrl+C to stop."

trap 'echo "Exiting..."; exit' SIGINT SIGTERM

while true; do 
    echo "The devil is in the details."
    sleep 10
done
