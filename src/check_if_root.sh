#!/usr/bin/env bash

# Script Name: check_if_root.sh
# Description: This script verifies if it is being run as root and provides a relevant message if not. Optional logging is included.
#              Exits 0 when running as root, 1 otherwise.
# Usage: ./check_if_root.sh [--log | -l]
#        Use --log or -l to enable logging to /var/log/check_if_root.log.

LOG_FILE="/var/log/check_if_root.log"
LOG_ENABLED=0

for arg in "$@"; do
    case $arg in
        --log|-l)
            LOG_ENABLED=1
            ;;
        *)
            echo "Unknown option: $arg" >&2
            echo "Usage: $0 [--log | -l]" >&2
            exit 2
            ;;
    esac
done

log_message() {
    if [ "${LOG_ENABLED}" -eq 1 ]; then
        # Non-root users usually can't write to /var/log; don't let that abort the check.
        if ! echo "$(date +"%Y-%m-%d %T"): $1" 2>/dev/null >> "${LOG_FILE}"; then
            echo "Warning: cannot write to ${LOG_FILE}; logging disabled." >&2
            LOG_ENABLED=0
        fi
    fi
}

check_root() {
    log_message "Starting root check."
    local user_id
    user_id="$(id -u)"
    if [ "${user_id}" -ne 0 ]; then
        echo "Error: This script must be run as root." >&2
        echo "You may try using: sudo bash $0" >&2
        log_message "Script attempted without root privileges by user ID ${user_id}."
        return 1
    else
        echo "Script is running with root privileges."
        log_message "Script running as root."
        return 0
    fi
}

main() {
    local exit_status=0
    # Additional code for root actions can go after a successful check.
    check_root || exit_status=$?

    if [ ${exit_status} -ne 0 ]; then
        log_message "Script exited with error."
    else
        log_message "Script completed successfully."
    fi
    exit ${exit_status}
}

main

