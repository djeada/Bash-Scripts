#!/usr/bin/env bash

# Script Name: cpu_usage.sh
# Description: Displays the current CPU usage.
# Usage: cpu_usage.sh
# Example: ./cpu_usage.sh

# To be implemented:
# - Add option to display CPU usage for a specific process.
# - Add option to display CPU usage for a specific user.

main() {

    # https://stackoverflow.com/questions/9229333/how-to-get-overall-cpu-usage-e-g-57-on-linux
    local prefix
    cpu_usage_total=$(top -b -n2 -p 1 | grep -F "Cpu(s)" | tail -1 | awk -F'id,' -v prefix="$prefix" '{ split($1, vs, ","); v=vs[length(vs)]; sub("%", "", v); printf "%s%.1f%%\n", prefix, 100 - v }')
    echo "Total CPU usage: $cpu_usage_total"

}

main "$@"
