#!/usr/bin/env bash
# Script Name: cpu_usage.sh
# Description: Displays the current CPU usage with options for per-core details and process filtering.
# Usage: ./cpu_usage.sh [ -p PROCESS_NAME ] [ -u USERNAME ] [ -n NUMBER ] [ -f FORMAT ] [ -i INTERVAL ] [ -c ] [ -h ]
# Options:
#   -p PROCESS_NAME   Display CPU usage for processes matching PROCESS_NAME.
#   -u USERNAME       Display top CPU consuming processes for USERNAME.
#   -n NUMBER         Number of processes to display (default is 10).
#   -f FORMAT         Output format: text (default) or json.
#   -i INTERVAL       Interval in seconds for monitoring continuously.
#   -c                Display per-core CPU usage.
#   -h                Show help message.

# Display usage information
usage() {
    cat <<EOF
Usage: $0 [ -p PROCESS_NAME ] [ -u USERNAME ] [ -n NUMBER ] [ -f FORMAT ] [ -i INTERVAL ] [ -c ] [ -h ]
Options:
  -p PROCESS_NAME   Display CPU usage for processes matching PROCESS_NAME.
  -u USERNAME       Display top CPU consuming processes for USERNAME.
  -n NUMBER         Number of processes to display (default is 10).
  -f FORMAT         Output format: text (default) or json.
  -i INTERVAL       Interval in seconds for monitoring continuously.
  -c                Display per-core CPU usage.
  -h                Show this help message.
EOF
    exit 1
}

# Check for required commands
check_required_commands() {
    local cmds=("ps" "awk" "uname" "grep" "top")
    for cmd in "${cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Error: Required command '$cmd' not found." >&2
            exit 1
        fi
    done
}

# Detect operating system type
detect_os() {
    local os_name
    os_name=$(uname -s)
    case "$os_name" in
        Linux*)  OS_TYPE="Linux" ;;
        Darwin*) OS_TYPE="macOS" ;;
        *)       OS_TYPE="Unknown" ;;
    esac
}

# Retrieve overall CPU usage
get_total_cpu_usage() {
    if [[ "$OS_TYPE" == "Linux" ]]; then
        # Use top in batch mode and extract the idle percentage
        local idle
        idle=$(top -bn1 | grep -i "Cpu(s)" | awk '{print $8}' 2>/dev/null)
        if [[ -n "$idle" ]]; then
            TOTAL_CPU_USAGE=$(awk -v idle="$idle" 'BEGIN {printf "%.2f%%", 100 - idle}')
        else
            TOTAL_CPU_USAGE="N/A"
        fi
    elif [[ "$OS_TYPE" == "macOS" ]]; then
        local idle
        idle=$(top -l 1 | grep "CPU usage" | awk '{print $7}' | sed 's/%//')
        if [[ -n "$idle" ]]; then
            TOTAL_CPU_USAGE=$(awk -v idle="$idle" 'BEGIN {printf "%.2f%%", 100 - idle}')
        else
            TOTAL_CPU_USAGE="N/A"
        fi
    else
        TOTAL_CPU_USAGE="N/A"
    fi
}

# Display per-core CPU usage
get_per_core_cpu_usage() {
    if [[ "$OS_TYPE" == "Linux" ]]; then
        if command -v mpstat &>/dev/null; then
            mpstat -P ALL 1 1 | awk '/Average/ && $2 ~ /^[0-9]+$/ {printf "CPU%s Usage: %.2f%%\n", $2, 100 - $(NF)}'
        else
            echo "mpstat command not found. Please install the sysstat package for per-core CPU usage."
        fi
    elif [[ "$OS_TYPE" == "macOS" ]]; then
        echo "Per-core CPU usage is not supported on macOS in this script."
    else
        echo "Unsupported OS type."
    fi
}

# Get top N CPU consuming processes (including header)
get_top_processes() {
    local number="$1"
    if [[ "$OS_TYPE" == "Linux" ]]; then
        ps -eo user,pid,%cpu,comm --sort=-%cpu | head -n $((number + 1))
    elif [[ "$OS_TYPE" == "macOS" ]]; then
        ps -Ao user,pid,%cpu,comm -r | head -n $((number + 1))
    else
        echo "Unsupported OS type."
    fi
}

# Get top N CPU consuming processes for a given user (including header)
get_top_processes_for_user() {
    local user="$1"
    local number="$2"
    if [[ "$OS_TYPE" == "Linux" ]]; then
        ps -eo user,pid,%cpu,comm --sort=-%cpu | awk -v usr="$user" '$1==usr' | head -n $((number))
    elif [[ "$OS_TYPE" == "macOS" ]]; then
        ps -Ao user,pid,%cpu,comm -r | awk -v usr="$user" '$1==usr' | head -n $((number))
    else
        echo "Unsupported OS type."
    fi
}

# Get CPU usage for processes matching a specific name
get_process_cpu_usage() {
    local proc="$1"
    if [[ "$OS_TYPE" == "Linux" ]]; then
        ps -eo user,pid,%cpu,comm | awk -v proc="$proc" 'tolower($4) ~ tolower(proc)'
    elif [[ "$OS_TYPE" == "macOS" ]]; then
        ps -Ao user,pid,%cpu,comm | awk -v proc="$proc" 'tolower($4) ~ tolower(proc)'
    else
        echo "Unsupported OS type."
    fi
}

# Output process list in JSON format; skips the header line and handles multi-word commands.
output_json() {
    local data
    data=$(cat)  # Read from STDIN
    echo "$data" | sed '1d' | awk '
    BEGIN {
        print "["
        sep = ""
    }
    {
        # Reconstruct command field (from 4th field onward)
        cmd = $4
        for(i = 5; i <= NF; i++) {
            cmd = cmd " " $i
        }
        printf "%s  {\"user\": \"%s\", \"pid\": %s, \"cpu\": %s, \"command\": \"%s\"}", sep, $1, $2, $3, cmd
        sep = ",\n"
    }
    END {
        print "\n]"
    }'
}

# Main function
main() {
    check_required_commands
    detect_os

    # Default parameter values
    local process=""
    local user=""
    local number=10
    local format="text"
    local interval=0
    local per_core=0

    # Parse command-line options
    while getopts ":p:u:n:f:i:ch" option; do
        case "${option}" in
            p) process="${OPTARG}" ;;
            u) user="${OPTARG}" ;;
            n) number="${OPTARG}" ;;
            f) format="${OPTARG}" ;;
            i) interval="${OPTARG}" ;;
            c) per_core=1 ;;
            h) usage ;;
            *) echo "Invalid option: -${OPTARG}" >&2; usage ;;
        esac
    done
    shift $((OPTIND - 1))

    # Validate that 'number' and 'interval' are numeric
    if ! [[ "$number" =~ ^[0-9]+$ ]]; then
        echo "Error: -n NUMBER must be an integer." >&2
        exit 1
    fi
    if ! [[ "$interval" =~ ^[0-9]+$ ]]; then
        echo "Error: -i INTERVAL must be an integer." >&2
        exit 1
    fi

    # Main monitoring loop
    while true; do
        get_total_cpu_usage

        if [[ "$format" == "json" ]]; then
            echo "{"
            echo "  \"total_cpu_usage\": \"${TOTAL_CPU_USAGE}\","
            if [[ "$per_core" -eq 1 ]]; then
                echo "  \"per_core_cpu_usage\": ["
                if [[ "$OS_TYPE" == "Linux" ]] && command -v mpstat &>/dev/null; then
                    mpstat -P ALL 1 1 | awk '
                    /Average/ && $2 ~ /^[0-9]+$/ {
                        usage = 100 - $(NF);
                        arr[NR] = sprintf("    {\"cpu\": \"%s\", \"usage\": %.2f}", $2, usage);
                        count++
                    }
                    END {
                        for(i = 1; i <= count; i++) {
                            printf "%s%s\n", arr[i], (i < count ? "," : "")
                        }
                    }'
                elif [[ "$OS_TYPE" == "macOS" ]]; then
                    echo "    {\"error\": \"Per-core CPU usage not supported on macOS.\"}"
                else
                    echo "    {\"error\": \"Unsupported OS or mpstat not available.\"}"
                fi
                echo "  ],"
            fi
            echo "  \"processes\": "
        else
            echo "Total CPU usage: ${TOTAL_CPU_USAGE}"
            if [[ "$per_core" -eq 1 ]]; then
                echo "Per-core CPU usage:"
                get_per_core_cpu_usage
            fi
        fi

        # Get process data based on provided options
        local proc_data
        if [[ -n "$process" ]]; then
            proc_data=$(get_process_cpu_usage "$process")
        elif [[ -n "$user" ]]; then
            proc_data=$(get_top_processes_for_user "$user" "$number")
        else
            proc_data=$(get_top_processes "$number")
        fi

        # Output process data in the chosen format
        if [[ "$format" == "json" ]]; then
            echo "$proc_data" | output_json
            echo "}"
        else
            echo "$proc_data"
        fi

        # If no interval is set, run only once.
        if [[ "$interval" -le 0 ]]; then
            break
        else
            sleep "$interval"
            echo    # add a newline for readability between updates
        fi
    done
}

main "$@"

