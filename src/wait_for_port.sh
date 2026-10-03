#!/usr/bin/env bash

# Script Name: wait_for_port.sh
# Description: Waits until a TCP port accepts connections (e.g. a database or
#              web server starting up in CI or docker-compose), then optionally
#              runs a command. Uses bash's /dev/tcp, so no netcat is required.
# Usage: wait_for_port.sh [-t timeout] [-i interval] [-q] host:port [-- command [args...]]
# Options:
#   -t timeout   Give up after this many seconds, 0 waits forever (default: 30).
#   -i interval  Seconds to sleep between connection attempts (default: 1).
#   -q           Quiet: only report failures.
#   -h           Show this help message.
# Examples:
#   wait_for_port.sh localhost:5432
#   wait_for_port.sh -t 60 db:3306 -- ./run_migrations.sh

set -uo pipefail

usage() {
    sed -n '3,/^$/p' "$0" | sed -e '/^$/d' -e 's/^# \{0,1\}//'
}

die() {
    echo "Error: $*" >&2
    exit 2
}

port_open() {
    local host="$1" port="$2"
    # shellcheck disable=SC2016 # expanded by the inner shell
    timeout 2 bash -c ': </dev/tcp/"$1"/"$2"' _ "$host" "$port" 2>/dev/null
}

main() {
    local timeout_s=30 interval=1 quiet=0
    local opt

    while getopts ":t:i:qh" opt; do
        case "$opt" in
            t) timeout_s="$OPTARG" ;;
            i) interval="$OPTARG" ;;
            q) quiet=1 ;;
            h) usage; exit 0 ;;
            :) die "option -$OPTARG requires an argument" ;;
            *) die "unknown option -$OPTARG" ;;
        esac
    done
    shift $((OPTIND - 1))

    [[ $# -ge 1 ]] || { usage >&2; exit 2; }
    [[ $timeout_s =~ ^[0-9]+$ ]] || die "timeout must be a non-negative integer"
    [[ $interval =~ ^[1-9][0-9]*$ ]] || die "interval must be a positive integer"
    command -v timeout >/dev/null 2>&1 || die "'timeout' (coreutils) is required"

    local target="$1"
    shift
    local host="${target%:*}" port="${target##*:}"
    [[ $target == *:* && -n $host ]] || die "target must be in host:port form (got '$target')"
    if [[ ! $port =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
        die "invalid port '$port'"
    fi

    ((quiet)) || echo "Waiting for $host:$port (timeout: ${timeout_s}s)..."
    local start=$SECONDS
    until port_open "$host" "$port"; do
        if ((timeout_s > 0 && SECONDS - start >= timeout_s)); then
            echo "Timed out after ${timeout_s}s waiting for $host:$port" >&2
            exit 1
        fi
        sleep "$interval"
    done
    ((quiet)) || echo "$host:$port is available after $((SECONDS - start))s."

    [[ ${1:-} == "--" ]] && shift
    if [[ $# -gt 0 ]]; then
        exec "$@"
    fi
}

main "$@"

