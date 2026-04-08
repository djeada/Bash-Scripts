#!/usr/bin/env bash

# Script Name: network_bandwidth.sh
# Description: Monitors network bandwidth usage in real time, detects high consumption,
#              traces usage to processes, and generates reports/logs.
# Usage: network_bandwidth.sh [options]
#
# Options:
#   -h, --help                Display this help message and exit.
#   -v, --verbose             Enable verbose output.
#   -I, --interface IFACE     Specify network interface to monitor (default: auto-detect).
#   -i, --interval SECONDS    Sampling interval in seconds (default: 2).
#   -t, --threshold KB/S      Alert threshold in KB/s for high bandwidth (default: 1000).
#   -n, --top N               Number of top processes to display (default: 10).
#   -c, --count COUNT         Number of samples to collect (default: unlimited).
#   -l, --log-file FILE       Log output to specified file.
#   -o, --output FILE         Save output to specified file.
#       --json                Output in JSON format.
#       --no-header           Do not display header row.
#
# Examples:
#   network_bandwidth.sh -I eth0
#   network_bandwidth.sh --interval 5 --threshold 5000
#   network_bandwidth.sh --top 5 --json
#   network_bandwidth.sh -I wlan0 -c 10 -l bandwidth.log

set -euo pipefail

# Default configurations
VERBOSE=false
INTERFACE=""
INTERVAL=2
THRESHOLD=1000
TOP_N=10
COUNT=0
LOG_FILE=""
LOG_ENABLED=false
OUTPUT_FILE=""
OUTPUT_JSON=false
NO_HEADER=false

# Function to display usage information
print_usage() {
    cat << EOF
Usage: $0 [options]

Options:
  -h, --help                Display this help message and exit.
  -v, --verbose             Enable verbose output.
  -I, --interface IFACE     Specify network interface to monitor (default: auto-detect).
  -i, --interval SECONDS    Sampling interval in seconds (default: 2).
  -t, --threshold KB/S      Alert threshold in KB/s for high bandwidth (default: 1000).
  -n, --top N               Number of top processes to display (default: 10).
  -c, --count COUNT         Number of samples to collect (default: unlimited).
  -l, --log-file FILE       Log output to specified file.
  -o, --output FILE         Save output to specified file.
      --json                Output in JSON format.
      --no-header           Do not display header row.

Examples:
  $0 -I eth0
  $0 --interval 5 --threshold 5000
  $0 --top 5 --json
  $0 -I wlan0 -c 10 -l bandwidth.log
EOF
}

# Function for logging
log_action() {
    local message="$1"
    if [[ "$LOG_ENABLED" == true ]]; then
        echo "$(date +"%Y-%m-%d %T"): $message" >> "$LOG_FILE"
    fi
    if [[ "$VERBOSE" == true ]]; then
        echo "$message"
    fi
}

# Check for required commands
check_required_commands() {
    local cmds=("awk" "cat")
    for cmd in "${cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Error: Required command '$cmd' not found." >&2
            exit 1
        fi
    done
}

# Detect the default network interface
detect_interface() {
    if [[ -n "$INTERFACE" ]]; then
        if [[ ! -d "/sys/class/net/$INTERFACE" ]]; then
            echo "Error: Interface '$INTERFACE' does not exist." >&2
            exit 1
        fi
        return
    fi

    # Try to find the default route interface
    if command -v ip &>/dev/null; then
        INTERFACE=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')
    fi

    # Fallback: pick the first non-lo interface from /sys/class/net
    if [[ -z "$INTERFACE" ]]; then
        for iface in /sys/class/net/*; do
            local name
            name=$(basename "$iface")
            if [[ "$name" != "lo" ]]; then
                INTERFACE="$name"
                break
            fi
        done
    fi

    if [[ -z "$INTERFACE" ]]; then
        echo "Error: Unable to detect a network interface. Specify one with -I." >&2
        exit 1
    fi

    log_action "Auto-detected interface: $INTERFACE"
}

# Read current RX and TX bytes from /sys/class/net
read_bytes() {
    local iface="$1"
    local rx tx
    rx=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null) || rx=0
    tx=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null) || tx=0
    echo "$rx $tx"
}

# Format bytes per second into a human-readable string
format_rate() {
    local bytes_per_sec="$1"
    if (( bytes_per_sec >= 1073741824 )); then
        awk -v b="$bytes_per_sec" 'BEGIN {printf "%.2f GB/s", b/1073741824}'
    elif (( bytes_per_sec >= 1048576 )); then
        awk -v b="$bytes_per_sec" 'BEGIN {printf "%.2f MB/s", b/1048576}'
    elif (( bytes_per_sec >= 1024 )); then
        awk -v b="$bytes_per_sec" 'BEGIN {printf "%.2f KB/s", b/1024}'
    else
        echo "${bytes_per_sec} B/s"
    fi
}

# Get top network-consuming processes using ss and /proc
get_top_processes() {
    local number="$1"

    if ! command -v ss &>/dev/null; then
        echo "  (ss not available — process tracing requires ss)"
        return
    fi

    # Collect socket info with process names
    local ss_output
    ss_output=$(ss -tunap 2>/dev/null | tail -n +2) || true

    if [[ -z "$ss_output" ]]; then
        echo "  (No active network connections found or insufficient permissions)"
        return
    fi

    # Extract and aggregate by process name, showing recv-q and send-q
    echo "$ss_output" | awk '
    {
        # The last field contains the process info: users:(("name",pid=N,fd=N))
        proc = $NF
        recv_q = $2
        send_q = $3

        # Extract process name from users:(("name",...))
        if (match(proc, /\(\("([^"]+)"/, arr)) {
            name = arr[1]
        } else {
            name = "-"
        }

        recv[name] += recv_q
        send[name] += send_q
        count[name]++
    }
    END {
        # Sort by total (recv+send) descending
        n = 0
        for (name in count) {
            total[n] = recv[name] + send[name]
            names[n] = name
            n++
        }

        # Simple selection sort
        for (i = 0; i < n - 1; i++) {
            max_idx = i
            for (j = i + 1; j < n; j++) {
                if (total[j] > total[max_idx]) {
                    max_idx = j
                }
            }
            if (max_idx != i) {
                tmp = total[i]; total[i] = total[max_idx]; total[max_idx] = tmp
                tmp = names[i]; names[i] = names[max_idx]; names[max_idx] = tmp
            }
        }

        printf "  %-20s %10s %10s %8s\n", "PROCESS", "RECV-Q", "SEND-Q", "CONNS"
        limit = (n < '"$number"') ? n : '"$number"'
        for (i = 0; i < limit; i++) {
            name = names[i]
            printf "  %-20s %10d %10d %8d\n", name, recv[name], send[name], count[name]
        }
    }'
}

# Get top processes in JSON format
get_top_processes_json() {
    local number="$1"

    if ! command -v ss &>/dev/null; then
        echo "[]"
        return
    fi

    local ss_output
    ss_output=$(ss -tunap 2>/dev/null | tail -n +2) || true

    if [[ -z "$ss_output" ]]; then
        echo "[]"
        return
    fi

    echo "$ss_output" | awk '
    {
        proc = $NF
        recv_q = $2
        send_q = $3

        if (match(proc, /\(\("([^"]+)"/, arr)) {
            name = arr[1]
        } else {
            name = "-"
        }

        recv[name] += recv_q
        send[name] += send_q
        count[name]++
    }
    END {
        n = 0
        for (name in count) {
            total[n] = recv[name] + send[name]
            names[n] = name
            n++
        }

        for (i = 0; i < n - 1; i++) {
            max_idx = i
            for (j = i + 1; j < n; j++) {
                if (total[j] > total[max_idx]) {
                    max_idx = j
                }
            }
            if (max_idx != i) {
                tmp = total[i]; total[i] = total[max_idx]; total[max_idx] = tmp
                tmp = names[i]; names[i] = names[max_idx]; names[max_idx] = tmp
            }
        }

        printf "["
        limit = (n < '"$number"') ? n : '"$number"'
        for (i = 0; i < limit; i++) {
            name = names[i]
            if (i > 0) printf ", "
            printf "{\"process\": \"%s\", \"recv_q\": %d, \"send_q\": %d, \"connections\": %d}", name, recv[name], send[name], count[name]
        }
        printf "]"
    }'
}

# Output a single sample in text format
output_text_sample() {
    local timestamp="$1"
    local rx_rate="$2"
    local tx_rate="$3"
    local rx_formatted="$4"
    local tx_formatted="$5"
    local high_usage="$6"

    echo "=== Network Bandwidth Report ==="
    echo "Timestamp : $timestamp"
    echo "Interface : $INTERFACE"
    echo "RX Rate   : $rx_formatted"
    echo "TX Rate   : $tx_formatted"

    if [[ "$high_usage" == true ]]; then
        echo "*** HIGH BANDWIDTH ALERT: Usage exceeds ${THRESHOLD} KB/s ***"
    fi

    echo ""
    echo "Active Network Processes:"
    get_top_processes "$TOP_N"
    echo ""
}

# Output a single sample in JSON format
output_json_sample() {
    local timestamp="$1"
    local rx_rate="$2"
    local tx_rate="$3"
    local rx_formatted="$4"
    local tx_formatted="$5"
    local high_usage="$6"

    local processes_json
    processes_json=$(get_top_processes_json "$TOP_N")

    cat << EOF
{
  "timestamp": "$timestamp",
  "interface": "$INTERFACE",
  "rx_bytes_per_sec": $rx_rate,
  "tx_bytes_per_sec": $tx_rate,
  "rx_rate": "$rx_formatted",
  "tx_rate": "$tx_formatted",
  "threshold_kbps": $THRESHOLD,
  "high_usage": $high_usage,
  "processes": $processes_json
}
EOF
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            print_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -I|--interface)
            if [[ -n "${2-}" ]]; then
                INTERFACE="$2"
                shift 2
            else
                echo "Error: --interface requires a value." >&2
                exit 1
            fi
            ;;
        -i|--interval)
            if [[ -n "${2-}" ]]; then
                INTERVAL="$2"
                shift 2
            else
                echo "Error: --interval requires a value." >&2
                exit 1
            fi
            ;;
        -t|--threshold)
            if [[ -n "${2-}" ]]; then
                THRESHOLD="$2"
                shift 2
            else
                echo "Error: --threshold requires a value." >&2
                exit 1
            fi
            ;;
        -n|--top)
            if [[ -n "${2-}" ]]; then
                TOP_N="$2"
                shift 2
            else
                echo "Error: --top requires a value." >&2
                exit 1
            fi
            ;;
        -c|--count)
            if [[ -n "${2-}" ]]; then
                COUNT="$2"
                shift 2
            else
                echo "Error: --count requires a value." >&2
                exit 1
            fi
            ;;
        -l|--log-file)
            if [[ -n "${2-}" ]]; then
                LOG_FILE="$2"
                LOG_ENABLED=true
                shift 2
            else
                echo "Error: --log-file requires a value." >&2
                exit 1
            fi
            ;;
        -o|--output)
            if [[ -n "${2-}" ]]; then
                OUTPUT_FILE="$2"
                shift 2
            else
                echo "Error: --output requires a value." >&2
                exit 1
            fi
            ;;
        --json)
            OUTPUT_JSON=true
            shift
            ;;
        --no-header)
            NO_HEADER=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            print_usage >&2
            exit 1
            ;;
    esac
done

# Validate numeric parameters
if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || [[ "$INTERVAL" -lt 1 ]]; then
    echo "Error: --interval must be a positive integer." >&2
    exit 1
fi
if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]]; then
    echo "Error: --threshold must be a non-negative integer." >&2
    exit 1
fi
if ! [[ "$TOP_N" =~ ^[0-9]+$ ]] || [[ "$TOP_N" -lt 1 ]]; then
    echo "Error: --top must be a positive integer." >&2
    exit 1
fi
if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
    echo "Error: --count must be a non-negative integer." >&2
    exit 1
fi

# Main monitoring function
main() {
    check_required_commands
    detect_interface

    # Redirect output to file if specified
    if [[ -n "$OUTPUT_FILE" ]]; then
        exec > >(tee -a "$OUTPUT_FILE")
    fi

    log_action "Starting network bandwidth monitoring on interface $INTERFACE"
    log_action "Sampling interval: ${INTERVAL}s, Alert threshold: ${THRESHOLD} KB/s"

    if [[ "$OUTPUT_JSON" == false && "$NO_HEADER" == false ]]; then
        echo "Monitoring network bandwidth on interface: $INTERFACE"
        echo "Sampling interval: ${INTERVAL}s | Alert threshold: ${THRESHOLD} KB/s"
        echo "Press Ctrl+C to stop."
        echo ""
    fi

    # Read initial bytes
    local initial
    initial=$(read_bytes "$INTERFACE")
    local prev_rx prev_tx
    prev_rx=$(echo "$initial" | awk '{print $1}')
    prev_tx=$(echo "$initial" | awk '{print $2}')

    sleep "$INTERVAL"

    local sample_num=0

    while true; do
        sample_num=$((sample_num + 1))

        local current
        current=$(read_bytes "$INTERFACE")
        local curr_rx curr_tx
        curr_rx=$(echo "$current" | awk '{print $1}')
        curr_tx=$(echo "$current" | awk '{print $2}')

        # Calculate rates (bytes per second)
        local rx_diff tx_diff rx_rate tx_rate
        rx_diff=$((curr_rx - prev_rx))
        tx_diff=$((curr_tx - prev_tx))
        rx_rate=$((rx_diff / INTERVAL))
        tx_rate=$((tx_diff / INTERVAL))

        # Format for display
        local rx_formatted tx_formatted
        rx_formatted=$(format_rate "$rx_rate")
        tx_formatted=$(format_rate "$tx_rate")

        # Check threshold (convert rate to KB/s for comparison)
        local rx_kbps tx_kbps total_kbps high_usage
        rx_kbps=$((rx_rate / 1024))
        tx_kbps=$((tx_rate / 1024))
        total_kbps=$((rx_kbps + tx_kbps))
        high_usage=false

        if [[ "$total_kbps" -ge "$THRESHOLD" ]]; then
            high_usage=true
            log_action "HIGH BANDWIDTH ALERT: ${total_kbps} KB/s on $INTERFACE (RX: ${rx_kbps} KB/s, TX: ${tx_kbps} KB/s)"
        fi

        local timestamp
        timestamp=$(date +"%Y-%m-%d %T")

        # Output the sample
        if [[ "$OUTPUT_JSON" == true ]]; then
            output_json_sample "$timestamp" "$rx_rate" "$tx_rate" "$rx_formatted" "$tx_formatted" "$high_usage"
        else
            output_text_sample "$timestamp" "$rx_rate" "$tx_rate" "$rx_formatted" "$tx_formatted" "$high_usage"
        fi

        log_action "Sample $sample_num: RX=$rx_formatted TX=$tx_formatted (total: ${total_kbps} KB/s)"

        # Update previous values
        prev_rx="$curr_rx"
        prev_tx="$curr_tx"

        # Check if we reached the count limit
        if [[ "$COUNT" -gt 0 && "$sample_num" -ge "$COUNT" ]]; then
            log_action "Completed $COUNT samples. Exiting."
            break
        fi

        sleep "$INTERVAL"
    done
}

main "$@"

