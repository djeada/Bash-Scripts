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
    
        TIMEFORMAT=%0lR
        time $1
        unset TIMEFORMAT

}

main "$@"
