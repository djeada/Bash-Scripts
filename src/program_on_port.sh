#!/usr/bin/env bash

# Script Name: program_on_port.sh
# Description: Script to check which programs are running on a specific port.
# Usage: program_on_port.sh port
#       port - a port to check
# Example: ./program_on_port.sh 8001

check_port() {
    # Check which programs are running on the specified port
    # $1: port number
    local port="$1"

    lsof -i tcp:"$port"
}

main() {
    # Main function to orchestrate the script

    if [ $# -ne 1 ]; then
        echo "Usage: program_on_port.sh port"
        echo "       port - a port to check"
        echo "Example: ./program_on_port.sh 8001"
        exit 1
    fi

    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]]; then
        echo "Error: $1 is not an integer"
        exit 1
    fi

    local port="$1"

    check_port "$port"
}

main "$@"

