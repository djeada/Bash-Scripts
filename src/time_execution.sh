#!/usr/bin/env bash

# Script Name: time_execution.sh
# Description: Displays the average time it takes for a command to execute.
# Usage: time_execution.sh 'command' [number of runs]
#        'command' is the command to execute (evaluated by the shell).
#        number of runs is optional and defaults to 10 if not provided.
# Example: ./time_execution.sh 'sleep 1' 20

main() {
    if [ -z "${1:-}" ] || [ $# -gt 2 ]; then
        echo "Usage: $0 'command' [number of runs]" >&2
        exit 1
    fi

    local command="$1"
    local N=${2:-10}
    local total_time=0

    if ! [[ "$N" =~ ^[0-9]+$ ]] || (( 10#$N == 0 )); then
        echo "Error: number of runs must be a positive integer." >&2
        exit 1
    fi
    N=$((10#$N))

    if ! command -v bc >/dev/null 2>&1; then
        echo "Error: this script requires 'bc'." >&2
        exit 1
    fi

    local start_time end_time
    for ((run = 0; run < N; run++)); do
        start_time=$(date +%s.%N)
        eval "$command"
        end_time=$(date +%s.%N)
        total_time=$(echo "$total_time + ($end_time - $start_time)" | bc)
    done

    local avg_time
    # bc prints .123 for values below 1; add the leading zero.
    avg_time=$(echo "scale=3; $total_time / $N" | bc | sed 's/^\./0./')
    echo "Average execution time for \"$command\" over $N runs: $avg_time seconds"
}

main "$@"

