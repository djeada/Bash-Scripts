#!/usr/bin/env bash

# Script Name: time_execution.sh
# Description: Displays the time it takes for a command to execute.
# Usage: time_execution.sh [command]
#        [command] is the command to execute.
# Example: ./time_execution.sh sleep 1

main() {

    if [ $# -ne 1 ]; then
        echo "Usage: time_execution.sh [command]"
        exit 1
    fi

    N=10
    total=0
    TIMEFORMAT=%0lR
    for i in $(seq 1 $N); do
        time=$( { time -p $1; } 2>&1 )
        total=$(echo "$total + $time" | bc)
    done
    unset TIMEFORMAT

    avg=$(echo "$total / $N" | bc)

    echo "Average execution time: $avg"

}

main "$@"
