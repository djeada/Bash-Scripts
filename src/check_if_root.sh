#!/usr/bin/env bash

# Script Name: check_if_root.sh
# Description: This script verifies if it is being run as root and provides a relevant message if not. Optional logging is included.
# Usage: ./check_if_root.sh [--log | -l]
#        Use --log or -l to enable logging.

LOG_FILE="/var/log/check_if_root.log"
LOG_ENABLED=0

for arg in "$@"; do
    case $arg in
        --log|-l)
            LOG_ENABLED=1
            shift # Remove --log or -l from processing
            ;;
        *)
            # Unknown option
            ;;
    esac
done

log_message() {
    if [ "${LOG_ENABLED}" -eq 1 ]; then
        echo "$(date +"%Y-%m-%d %T"): $1" >> "${LOG_FILE}"
    fi
}

check_root() {
    log_message "Starting root check."
    USER_ID="$(id -u)"
    if [ "${USER_ID}" -ne 0 ]; then
        echo "Error: This script must be run as root."
        echo "You may try using: sudo bash $0"
        log_message "Script attempted without root privileges by user ID ${USER_ID}."
        return 1
    else
        echo "Script is running with root privileges."
        log_message "Script running as root."
        return 0
    fi
}

main() {
    if check_root; then
        # Additional code for root actions can go here
        :
    fi
    local exit_status=$?
    if [ ${exit_status} -ne 0 ]; then
        log_message "Script exited with error."
    else
        log_message "Script completed successfully."
    fi
    exit ${exit_status}
}

main
