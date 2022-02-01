#!/usr/bin/env bash

# Script Name: system_info.sh
# Description: Displays information about the system.
# Usage: system_info.sh
# Example: ./system_info.sh

main() {

    echo -e "Memory usage: \n$(free -h)"
    echo -e "\nDisk usage: \n$(df -h)"
    echo -e "\nUptime: $(uptime)"

}

main "$@"

