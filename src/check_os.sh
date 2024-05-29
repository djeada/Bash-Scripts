#!/usr/bin/env bash

# Script Name: check_os.sh
# Description: Identifies the operating system of the current host and outputs the result.
# Usage: ./check_os.sh [--json] [--log]

LOG_FILE="/var/log/check_os.log"
JSON_OUTPUT=0
LOG_ENABLED=0

log_action() {
    [ $LOG_ENABLED -eq 1 ] && echo "$(date +"%Y-%m-%d %T"): $1" >> $LOG_FILE
}

output() {
    if [ $JSON_OUTPUT -eq 1 ]; then
        echo "{\"platform\":\"$1\", \"distro\":\"$2\", \"version\":\"$3\"}"
    else
        echo "Platform: $1"
        [ -n "$2" ] && echo "Distro: $2"
        [ -n "$3" ] && echo "Version: $3"
    fi
    log_action "Detected OS: Platform=$1, Distro=$2, Version=$3"
}

check_os() {
    local os_name=$(uname)
    local distro=""
    local version=""

    case $os_name in
        Darwin)
            version=$(sw_vers -productVersion)
            output "Mac OS X" "" "$version"
            ;;
        Linux)
            if [ -f /etc/os-release ]; then
                distro=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
                version=$(awk -F= '/^VERSION_ID/{print $2}' /etc/os-release | tr -d '"')
            else
                distro="Unknown"
                version="Unknown"
            fi
            output "GNU/Linux" "$distro" "$version"
            ;;
        MINGW32_NT* | MINGW64_NT*)
            arch=$(uname -m)
            if [ "$arch" == "x86_64" ]; then
                output "Windows NT" "" "64-bit"
            else
                output "Windows NT" "" "32-bit"
            fi
            ;;
        *)
            output "Unsupported" "" ""
            ;;
    esac
}

while [ $# -gt 0 ]; do
    case "$1" in
        --json)
            JSON_OUTPUT=1
            ;;
        --log)
            LOG_ENABLED=1
            ;;
        *)
            echo "Invalid option: $1"
            exit 1
            ;;
    esac
    shift
done

check_os
