#!/usr/bin/env bash

# Script Name: program_on_port.sh
# Description: Script to check which programs are using a specific port (TCP or UDP).
#              Without root privileges only your own processes are shown.
# Usage: program_on_port.sh port
#       port - a port to check (1-65535)
# Example: ./program_on_port.sh 8001

check_port() {
    # Check which programs are using the specified port
    # $1: port number
    local port="$1"

    if ! lsof -i :"$port"; then
        echo "No program found using port $port." >&2
        return 1
    fi
}

main() {
    # Main function to orchestrate the script

    if [ $# -ne 1 ]; then
        {
            echo "Usage: program_on_port.sh port"
            echo "       port - a port to check"
            echo "Example: ./program_on_port.sh 8001"
        } >&2
        exit 1
    fi

    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]] || (( 10#$1 < 1 || 10#$1 > 65535 )); then
        echo "Error: $1 is not a valid port number (1-65535)" >&2
        exit 1
    fi

    if ! command -v lsof >/dev/null 2>&1; then
        echo "Error: this script requires 'lsof'." >&2
        exit 1
    fi

    check_port "$((10#$1))"
}

main "$@"

