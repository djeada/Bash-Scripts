#!/usr/bin/env bash

# Script Name: time_execution.sh
# Description: Displays the average time it takes for a command to execute.
# Usage: time_execution.sh [command]
#        [command] is the command to execute.
# Example: ./time_execution.sh sleep 1

main() {

    command="$*"
    if [ -z "$command" ]; then
        echo "Usage: time_execution.sh [command]"
        exit 1
    fi

    N=10
    total="0.0"
    TIMEFORMAT=%0lR
    for i in $(seq 1 $N); do
        time_slice=$( { time -p "$command"; } 2>&1 )
        # commas should be replaced with dots
        time_slice=$(sed -r 's/[,]+/./g' <<< "$time_slice")
        # using regex, extract only the number while ignoring everything else
        time_slice=$(echo "$time_slice"| awk '{for(i=1;i<=NF;i++)if($i~/^-?[0-9]+\.[0-9]+$/){print $i}}')
        # we may get more than one match, but we only want a single number
        time_slice=$(echo "$time_slice" | awk 'FNR <= 1')
        total=$(echo "scale=10; $total + $time_slice" | bc)
    done
    unset TIMEFORMAT

    avg=$(echo "scale=10;$total / $N" | bc)
    echo "$avg" | sed -e 's/[0]*$//g'
}

main "$@"
