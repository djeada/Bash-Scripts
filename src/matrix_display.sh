#!/bin/bash

# Colors
GREEN="\033[0;32m"
LIGHT_GREEN="\033[1;32m"
END_COLOR="\033[0m"

# Matrix characters
CHARS="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

# Calculate columns and rows
COLS=$(tput cols)
ROWS=$(tput lines)
COLUMN_SPEEDS=()

# Initialize speeds for each column
for (( c=1; c<=$COLS; c++ )); do
    COLUMN_SPEEDS[$c]=$(( ( RANDOM % 5 ) + 1 ))
done

print_char() {
    local col=$1
    local char=${CHARS:$(( RANDOM % ${#CHARS} )):1}
    if [[ $(( RANDOM % 5 )) -eq 1 ]]; then
        # Occasionally print a brighter green
        echo -ne "\033[$(( RANDOM % ROWS + 1 ));${col}f$LIGHT_GREEN$char$END_COLOR"
    else
        echo -ne "\033[$(( RANDOM % ROWS + 1 ));${col}f$GREEN$char$END_COLOR"
    fi
}

# Infinite loop to keep the matrix going
while :; do
    for (( c=1; c<=$COLS; c++ )); do
        if (( RANDOM % COLUMN_SPEEDS[$c] == 1 )); then
            print_char $c
        fi
    done
    sleep 0.1
done

