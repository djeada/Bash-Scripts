#!/usr/bin/env bash

# Script Name: time_execution.sh
# Description: Displays the average time it takes for a command to execute.
# Usage: time_execution.sh command [number of runs]
#        command is the command to execute.
#        number of runs is optional and defaults to 10 if not provided.
# Example: ./time_execution.sh 'sleep 1' 20

main() {

    command="$1"
    N=${2:-10}

    if [ -z "$command" ]; then
        echo "Usage: time_execution.sh command [number of runs]"
        exit 1
    fi

    if ! command -v bc >/dev/null; then
        echo "This script requires 'bc'. Please install 'bc' and run this script again."
        exit 1
    fi

    total="0.0"
    TIMEFORMAT=%0lR
    for i in $(seq 1 $N); do
        time_slice=$( { time -p $command; } 2>&1 | grep real | awk '{print $2}')
        time_slice=$(sed -r 's/[,]+/./g' <<< "$time_slice")
        total=$(echo "scale=10; $total + $time_slice" | bc)
    done
    unset TIMEFORMAT

    avg=$(echo "scale=10;$total / $N" | bc)
    echo "Average execution time for \"$command\" over $N runs: $avg sec"
}

main "$@"
