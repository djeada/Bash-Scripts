#!/usr/bin/env bash

# Script Name: cpu_usage.sh
# Description: Displays the current CPU usage.
# Usage: ./cpu_usage.sh [ -p PROCESS_NAME | -u USERNAME ]
# Example: ./cpu_usage.sh -p firefox -u root

# Function to get the overall CPU usage
get_total_cpu_usage() {
    top -bn1 | grep "Cpu(s)" | sed -r 's/\,([0-9]{1,2})\b/.\1/g' |  sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}'
}

# Function to get the top 10 CPU consuming processes
get_top_processes() {
    echo "Top 10 CPU consuming processes:"
    ps aux --sort=-%cpu | awk '{print $1, $2, $3, $11}' | head -n 11
}

# Function to get the top 10 CPU consuming processes for a specific user
get_top_processes_for_user() {
    local user="$1"
    echo "Top 10 CPU consuming processes for user '$user':"
    ps aux --sort=-%cpu | awk -v user="$user" '{if($1==user) print $1, $2, $3, $11}' | head -n 11
}

# Function to get CPU usage for a specific process name
get_process_cpu_usage() {
    local process="$1"
    echo "CPU usage for processes matching '$process':"
    pgrep -fl "$process" | while read -r pid; do
        ps -p "$pid" -o user=,pid=,%cpu=,cmd= --no-headers | awk '{print $1, $2, $3, $4}'
    done
}


main() {
    local process
    local user

    echo "Total CPU usage: $(get_total_cpu_usage)"

    while getopts ":p:u:" option; do
        case "${option}" in
            p)
                process=${OPTARG}
                ;;
            u)
                user=${OPTARG}
                ;;
            *)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
        esac
    done
    shift $((OPTIND -1))

    if [[ -n "$process" ]]; then
        get_process_cpu_usage "$process"
        exit 0
    fi

    if [[ -n "$user" ]]; then
        get_top_processes_for_user "$user"
    else
        get_top_processes
    fi
}

main "$@"

