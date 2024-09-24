#!/usr/bin/env bash

# Script Name: cpu_usage.sh
# Description: Displays the current CPU usage with various options, including per-core usage.
# Usage: ./cpu_usage.sh [ -p PROCESS_NAME ] [ -u USERNAME ] [ -n NUMBER ] [ -f FORMAT ] [ -i INTERVAL ] [ -c ] [ -h ]
# Options:
#   -p PROCESS_NAME   Display CPU usage for processes matching PROCESS_NAME.
#   -u USERNAME       Display top CPU consuming processes for USERNAME.
#   -n NUMBER         Number of processes to display (default is 10).
#   -f FORMAT         Output format: text (default), json.
#   -i INTERVAL       Interval in seconds for monitoring over time.
#   -c                Display per-core CPU usage.
#   -h                Show help message.

# Function to display usage
usage() {
    echo "Usage: $0 [ -p PROCESS_NAME ] [ -u USERNAME ] [ -n NUMBER ] [ -f FORMAT ] [ -i INTERVAL ] [ -c ] [ -h ]"
    echo "Options:"
    echo "  -p PROCESS_NAME   Display CPU usage for processes matching PROCESS_NAME."
    echo "  -u USERNAME       Display top CPU consuming processes for USERNAME."
    echo "  -n NUMBER         Number of processes to display (default is 10)."
    echo "  -f FORMAT         Output format: text (default), json."
    echo "  -i INTERVAL       Interval in seconds for monitoring over time."
    echo "  -c                Display per-core CPU usage."
    echo "  -h                Show help message."
    exit 1
}

# Function to check for required commands
check_required_commands() {
    local cmds=("ps" "awk" "uname" "grep" "top")
    for cmd in "${cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: Required command '$cmd' not found" >&2
            exit 1
        fi
    done
}

# Function to detect OS type
detect_os() {
    local os_name
    os_name=$(uname -s)
    case "$os_name" in
        Linux*)     OS_TYPE="Linux" ;;
        Darwin*)    OS_TYPE="macOS" ;;
        *)          OS_TYPE="Unknown" ;;
    esac
}

# Function to get the overall CPU usage
get_total_cpu_usage() {
    if [ "$OS_TYPE" = "Linux" ]; then
        local idle
        idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}')
        TOTAL_CPU_USAGE=$(awk -v idle="$idle" 'BEGIN {printf "%.2f%%", 100 - idle}')
    elif [ "$OS_TYPE" = "macOS" ]; then
        local idle
        idle=$(top -l 1 | grep "CPU usage" | awk '{print $7}' | sed 's/%//')
        TOTAL_CPU_USAGE=$(awk -v idle="$idle" 'BEGIN {printf "%.2f%%", 100 - idle}')
    else
        TOTAL_CPU_USAGE="N/A"
    fi
}

# Function to get per-core CPU usage
get_per_core_cpu_usage() {
    if [ "$OS_TYPE" = "Linux" ]; then
        if command -v mpstat &> /dev/null; then
            mpstat -P ALL 1 1 | awk '/Average/ && $2 ~ /[0-9]+/ {printf "CPU%s Usage: %.2f%%\n", $2, 100 - $NF}'
        else
            echo "mpstat command not found. Please install sysstat package to get per-core CPU usage."
        fi
    elif [ "$OS_TYPE" = "macOS" ]; then
        echo "Per-core CPU usage is not supported on macOS in this script."
    else
        echo "Unsupported OS type."
    fi
}

# Function to get the top N CPU consuming processes
get_top_processes() {
    local number="$1"
    if [ "$OS_TYPE" = "Linux" ]; then
        ps -eo user,pid,%cpu,comm --sort=-%cpu | head -n "$((number + 1))"
    elif [ "$OS_TYPE" = "macOS" ]; then
        ps -Ao user,pid,%cpu,comm -r | head -n "$((number + 1))"
    else
        echo "Unsupported OS type."
    fi
}

# Function to get the top N CPU consuming processes for a specific user
get_top_processes_for_user() {
    local user="$1"
    local number="$2"
    if [ "$OS_TYPE" = "Linux" ]; then
        ps -eo user,pid,%cpu,comm --sort=-%cpu | awk -v user="$user" '$1==user' | head -n "$number"
    elif [ "$OS_TYPE" = "macOS" ]; then
        ps -Ao user,pid,%cpu,comm -r | awk -v user="$user" '$1==user' | head -n "$number"
    else
        echo "Unsupported OS type."
    fi
}

# Function to get CPU usage for a specific process name
get_process_cpu_usage() {
    local process="$1"
    if [ "$OS_TYPE" = "Linux" ]; then
        ps -eo user,pid,%cpu,comm | grep -i "$process" | grep -v grep
    elif [ "$OS_TYPE" = "macOS" ]; then
        ps -Ao user,pid,%cpu,comm | grep -i "$process" | grep -v grep
    else
        echo "Unsupported OS type."
    fi
}

# Function to output in JSON format
output_json() {
    local data="$1"
    echo "$data" | awk '
    BEGIN {
        print "["
    }
    NR>1 {
        printf "%s{\n", separator
        printf "  \"user\": \"%s\",\n", $1
        printf "  \"pid\": %s,\n", $2
        printf "  \"cpu\": %s,\n", $3
        printf "  \"command\": \"%s\"\n", $4
        printf "}"
        separator=",\n"
    }
    END {
        print "\n]"
    }'
}

main() {
    check_required_commands
    detect_os

    local process=""
    local user=""
    local number=10
    local format="text"
    local interval=0
    local per_core=0

    while getopts ":p:u:n:f:i:ch" option; do
        case "${option}" in
            p) process=${OPTARG} ;;
            u) user=${OPTARG} ;;
            n) number=${OPTARG} ;;
            f) format=${OPTARG} ;;
            i) interval=${OPTARG} ;;
            c) per_core=1 ;;
            h) usage ;;
            *) echo "Invalid option: -$OPTARG" >&2; usage ;;
        esac
    done
    shift $((OPTIND -1))

    if ! [[ "$number" =~ ^[0-9]+$ ]]; then
        echo "Error: Number of processes (-n) must be an integer."
        exit 1
    fi

    if ! [[ "$interval" =~ ^[0-9]+$ ]]; then
        echo "Error: Interval (-i) must be an integer."
        exit 1
    fi

    while true; do
        get_total_cpu_usage
        if [ "$format" = "json" ]; then
            echo "{"
            echo "  \"total_cpu_usage\": \"$TOTAL_CPU_USAGE\","
            if [ "$per_core" -eq 1 ]; then
                echo "  \"per_core_cpu_usage\": ["
                if [ "$OS_TYPE" = "Linux" ] && command -v mpstat &> /dev/null; then
                    mpstat -P ALL 1 1 | awk '/Average/ && $2 ~ /[0-9]+/ {printf "    {\"cpu\": \"%s\", \"usage\": %.2f}%s\n", $2, 100 - $NF, separator; separator=",\n"}'
                    echo ""
                elif [ "$OS_TYPE" = "macOS" ]; then
                    echo "    {\"error\": \"Per-core CPU usage not supported on macOS.\"}"
                else
                    echo "    {\"error\": \"Unsupported OS or mpstat not available.\"}"
                fi
                echo "  ],"
            fi
            echo "  \"processes\":"
        else
            echo "Total CPU usage: $TOTAL_CPU_USAGE"
            if [ "$per_core" -eq 1 ]; then
                echo "Per-core CPU usage:"
                get_per_core_cpu_usage
            fi
        fi

        if [[ -n "$process" ]]; then
            data=$(get_process_cpu_usage "$process")
        elif [[ -n "$user" ]]; then
            data=$(get_top_processes_for_user "$user" "$number")
        else
            data=$(get_top_processes "$number")
        fi

        if [ "$format" = "json" ]; then
            output_json "$data"
            echo "}"
        else
            echo "$data"
        fi

        if [ "$interval" -le 0 ]; then
            break
        else
            sleep "$interval"
        fi
    done
}

main "$@"
