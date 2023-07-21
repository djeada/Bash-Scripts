#!/usr/bin/env bash

# Script Name: conditionals.sh
# Description: Demonstrates the use of the case statement.
# Usage: ./conditionals.sh
# Example: ./conditionals.sh

read -rp "Please type a 'y' for YES or 'n' for NO: " input

case "$input" in
    [nN] )
        echo "NO" ;;
    [yY] )
        echo "YES" ;;
    * )
        echo "Invalid input. Please type 'y' for YES or 'n' for NO." ;;
esac

