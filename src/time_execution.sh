#!/usr/bin/env bash

# Script Name: time_execution.sh
# Description: Displays the average time it takes for a command to execute.
# Usage: time_execution.sh 'command' [number of runs]
#        'command' is the command to execute.
#        number of runs is optional and defaults to 10 if not provided.
# Example: ./time_execution.sh 'sleep 1' 20

main() {
    if [ -z "$1" ]; then
        echo "Usage: $0 'command' [number of runs]"
        exit 1
    fi

    local command="$1"
    local N=${2:-10}
    local total_time=0

    for _ in $(seq 1 "$N"); do
        local start_time=$(date +%s.%N)
        eval "$command"
        local end_time=$(date +%s.%N)
        total_time=$(echo "$total_time + ($end_time - $start_time)" | bc)
    done

    local avg_time=$(echo "scale=3; $total_time / $N" | bc)
    echo "Average execution time for \"$command\" over $N runs: $avg_time seconds"
}

main "$@"
