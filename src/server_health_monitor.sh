#!/usr/bin/env bash

# Script Name: server_health_monitor.sh
# Description: Continuously monitors server health by tracking CPU usage, memory usage,
#              and disk space utilization. Sends email alerts when thresholds are exceeded
#              and logs all detected issues for audit and analysis.
# Usage: ./server_health_monitor.sh [options]
# Options:
#   -h, --help                    Display this help message and exit.
#   -i, --interval SECONDS        Monitoring interval in seconds (default: 60).
#   -c, --cpu-threshold PERCENT   CPU usage alert threshold (default: 90).
#   -m, --mem-threshold PERCENT   Memory usage alert threshold (default: 90).
#   -d, --disk-threshold PERCENT  Disk usage alert threshold (default: 90).
#   -l, --log-file FILE           Log file path (default: /var/log/server_health.log).
#   -e, --email ADDRESS           Email address for alert notifications.
#       --once                    Run a single check and exit (no continuous monitoring).
#       --no-email                Disable email alerts (log only).
# Example:
#   ./server_health_monitor.sh -i 120 -c 85 -m 80 -d 75 -e admin@example.com

set -euo pipefail

# Default configurations
INTERVAL=60
CPU_THRESHOLD=90
MEM_THRESHOLD=90
DISK_THRESHOLD=90
LOG_FILE="/var/log/server_health.log"
EMAIL=""
RUN_ONCE=false
EMAIL_ENABLED=true

# Display usage information
print_usage() {
    cat << EOF
Usage: $0 [options]

Options:
  -h, --help                    Display this help message and exit.
  -i, --interval SECONDS        Monitoring interval in seconds (default: 60).
  -c, --cpu-threshold PERCENT   CPU usage alert threshold (default: 90).
  -m, --mem-threshold PERCENT   Memory usage alert threshold (default: 90).
  -d, --disk-threshold PERCENT  Disk usage alert threshold (default: 90).
  -l, --log-file FILE           Log file path (default: /var/log/server_health.log).
  -e, --email ADDRESS           Email address for alert notifications.
      --once                    Run a single check and exit (no continuous monitoring).
      --no-email                Disable email alerts (log only).

Examples:
  $0 -i 120 -c 85 -m 80 -d 75 -e admin@example.com
  $0 --once --no-email -l /tmp/health.log
  $0 --interval 30 --email admin@example.com

EOF
}

# Log a message to the log file with a timestamp
log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date +"%Y-%m-%d %T")"
    local log_entry="[$timestamp] [$level] $message"

    echo "$log_entry" >> "$LOG_FILE"
    echo "$log_entry"
}

# Send an email alert
send_alert() {
    local subject="$1"
    local body="$2"

    if [[ "$EMAIL_ENABLED" == true && -n "$EMAIL" ]]; then
        if command -v mail &>/dev/null; then
            echo "$body" | mail -s "$subject" "$EMAIL"
            log_message "INFO" "Alert email sent to $EMAIL: $subject"
        else
            log_message "WARN" "mail command not found. Cannot send email alert: $subject"
        fi
    fi
}

# Get current CPU usage percentage (integer)
get_cpu_usage() {
    local idle
    idle=$(top -bn1 | grep -i "Cpu(s)" | awk '{print $8}' 2>/dev/null)
    if [[ -n "$idle" ]]; then
        awk -v idle="$idle" 'BEGIN {printf "%d", 100 - idle}'
    else
        echo "0"
    fi
}

# Get current memory usage percentage (integer)
get_mem_usage() {
    local meminfo
    meminfo=$(grep -E 'MemTotal|MemAvailable' /proc/meminfo)
    local total available used_percent
    total=$(echo "$meminfo" | grep MemTotal | awk '{print $2}')
    available=$(echo "$meminfo" | grep MemAvailable | awk '{print $2}')

    if [[ "$total" -gt 0 ]]; then
        used_percent=$(( (total - available) * 100 / total ))
        echo "$used_percent"
    else
        echo "0"
    fi
}

# Get the highest disk usage percentage across all mounted filesystems
get_disk_usage() {
    df -h --output=pcent 2>/dev/null | grep -v "Use%" | tr -d ' %' | sort -rn | head -n 1
}

# Check CPU usage against threshold
check_cpu() {
    local usage
    usage=$(get_cpu_usage)

    if [[ "$usage" -ge "$CPU_THRESHOLD" ]]; then
        local msg="CPU usage is at ${usage}% (threshold: ${CPU_THRESHOLD}%)"
        log_message "ALERT" "$msg"
        send_alert "Server Health Alert: High CPU Usage" "$msg on $(hostname) at $(date)"
    else
        log_message "INFO" "CPU usage: ${usage}% (OK)"
    fi
}

# Check memory usage against threshold
check_memory() {
    local usage
    usage=$(get_mem_usage)

    if [[ "$usage" -ge "$MEM_THRESHOLD" ]]; then
        local msg="Memory usage is at ${usage}% (threshold: ${MEM_THRESHOLD}%)"
        log_message "ALERT" "$msg"
        send_alert "Server Health Alert: High Memory Usage" "$msg on $(hostname) at $(date)"
    else
        log_message "INFO" "Memory usage: ${usage}% (OK)"
    fi
}

# Check disk usage against threshold
check_disk() {
    local usage
    usage=$(get_disk_usage)

    if [[ -z "$usage" ]]; then
        log_message "WARN" "Unable to determine disk usage."
        return
    fi

    if [[ "$usage" -ge "$DISK_THRESHOLD" ]]; then
        local msg="Disk usage is at ${usage}% (threshold: ${DISK_THRESHOLD}%)"
        log_message "ALERT" "$msg"
        send_alert "Server Health Alert: High Disk Usage" "$msg on $(hostname) at $(date)"
    else
        log_message "INFO" "Disk usage: ${usage}% (OK)"
    fi
}

# Run a single health check cycle
run_health_check() {
    log_message "INFO" "--- Health check started ---"
    check_cpu
    check_memory
    check_disk
    log_message "INFO" "--- Health check completed ---"
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            print_usage
            exit 0
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
        -c|--cpu-threshold)
            if [[ -n "${2-}" ]]; then
                CPU_THRESHOLD="$2"
                shift 2
            else
                echo "Error: --cpu-threshold requires a value." >&2
                exit 1
            fi
            ;;
        -m|--mem-threshold)
            if [[ -n "${2-}" ]]; then
                MEM_THRESHOLD="$2"
                shift 2
            else
                echo "Error: --mem-threshold requires a value." >&2
                exit 1
            fi
            ;;
        -d|--disk-threshold)
            if [[ -n "${2-}" ]]; then
                DISK_THRESHOLD="$2"
                shift 2
            else
                echo "Error: --disk-threshold requires a value." >&2
                exit 1
            fi
            ;;
        -l|--log-file)
            if [[ -n "${2-}" ]]; then
                LOG_FILE="$2"
                shift 2
            else
                echo "Error: --log-file requires a value." >&2
                exit 1
            fi
            ;;
        -e|--email)
            if [[ -n "${2-}" ]]; then
                EMAIL="$2"
                shift 2
            else
                echo "Error: --email requires a value." >&2
                exit 1
            fi
            ;;
        --once)
            RUN_ONCE=true
            shift
            ;;
        --no-email)
            EMAIL_ENABLED=false
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            print_usage
            exit 1
            ;;
    esac
done

# Validate numeric inputs
for param_name in INTERVAL CPU_THRESHOLD MEM_THRESHOLD DISK_THRESHOLD; do
    param_value="${!param_name}"
    if ! [[ "$param_value" =~ ^[0-9]+$ ]]; then
        echo "Error: $param_name must be a positive integer." >&2
        exit 1
    fi
done

# Validate threshold ranges
for param_name in CPU_THRESHOLD MEM_THRESHOLD DISK_THRESHOLD; do
    param_value="${!param_name}"
    if [[ "$param_value" -lt 1 || "$param_value" -gt 100 ]]; then
        echo "Error: $param_name must be between 1 and 100." >&2
        exit 1
    fi
done

# Ensure the log file directory exists and is writable
log_dir="$(dirname "$LOG_FILE")"
if [[ ! -d "$log_dir" ]]; then
    mkdir -p "$log_dir" 2>/dev/null || {
        echo "Error: Cannot create log directory: $log_dir" >&2
        exit 1
    }
fi

# Main execution
log_message "INFO" "Server health monitor started."
log_message "INFO" "Thresholds - CPU: ${CPU_THRESHOLD}%, Memory: ${MEM_THRESHOLD}%, Disk: ${DISK_THRESHOLD}%"
log_message "INFO" "Monitoring interval: ${INTERVAL}s"

if [[ "$RUN_ONCE" == true ]]; then
    run_health_check
else
    while true; do
        run_health_check
        sleep "$INTERVAL"
    done
fi
