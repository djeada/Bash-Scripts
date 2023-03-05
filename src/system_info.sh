#!/usr/bin/env bash

# Script Name: system_info.sh
# Description: Displays information about the system.
# Usage: system_info.sh
# Example: ./system_info.sh

set -euo pipefail  # set Bash strict mode

# Constants
readonly SCRIPT_NAME=$(basename "${0}")

# Functions

print_usage() {
  cat << EOF
Usage: ${SCRIPT_NAME}
Displays information about the system.
EOF
}

print_help() {
  cat << EOF
${SCRIPT_NAME} - Display information about the system.

Usage: ${SCRIPT_NAME} [OPTIONS]

Options:
  -h, --help  Display this help message and exit.
EOF
}

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
  shift
done

# Main function
main() {
  echo -e "Memory usage: \n$(free -h)"
  echo -e "\nDisk usage (top 10):"
  echo "$(df -Ph | awk '{ if(NR==1) print $0; else print $0 | "sort -k 5 -h -r | head"}')"
  echo -e "\nUptime: $(uptime)"
  echo -e "\nCPU Info: \n$(lscpu)"
  echo -e "\nNetwork Interfaces: \n$(ip -br address)"
  echo -e "\nRunning Processes: \n$(ps aux)"
}

main "$@"
