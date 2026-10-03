#!/usr/bin/env bash

# Script Name: retry.sh
# Description: Runs a command and retries it with exponential backoff until it
#              succeeds or the attempt limit is reached. Exits with the last
#              exit code of the command.
# Usage: retry.sh [-n attempts] [-d delay] [-b factor] [-m max_delay] [-q] -- command [args...]
# Options:
#   -n attempts   Maximum number of attempts (default: 5).
#   -d delay      Initial delay between attempts in seconds (default: 1).
#   -b factor     Multiply the delay by this integer after each failure (default: 2).
#   -m max_delay  Upper bound for the delay in seconds (default: 60).
#   -q            Quiet: do not print retry messages.
#   -h            Show this help message.
# Examples:
#   retry.sh -- curl -fsS https://example.com/health
#   retry.sh -n 10 -d 2 -b 1 -- ping -c1 192.168.1.1

set -uo pipefail

usage() {
    sed -n '3,/^$/p' "$0" | sed -e '/^$/d' -e 's/^# \{0,1\}//'
}

die() {
    echo "Error: $*" >&2
    exit 2
}

is_uint() {
    [[ $1 =~ ^[0-9]+$ ]]
}

main() {
    local attempts=5 delay=1 factor=2 max_delay=60 quiet=0
    local opt

    while getopts ":n:d:b:m:qh" opt; do
        case "$opt" in
            n) attempts="$OPTARG" ;;
            d) delay="$OPTARG" ;;
            b) factor="$OPTARG" ;;
            m) max_delay="$OPTARG" ;;
            q) quiet=1 ;;
            h) usage; exit 0 ;;
            :) die "option -$OPTARG requires an argument" ;;
            *) die "unknown option -$OPTARG" ;;
        esac
    done
    shift $((OPTIND - 1))
    [[ ${1:-} == "--" ]] && shift

    [[ $# -gt 0 ]] || { usage >&2; exit 2; }
    for value in "$attempts" "$delay" "$factor" "$max_delay"; do
        is_uint "$value" || die "numeric options must be non-negative integers (got '$value')"
    done
    ((attempts >= 1)) || die "attempts must be at least 1"

    local attempt status
    for ((attempt = 1; ; attempt++)); do
        "$@"
        status=$?
        ((status == 0)) && return 0

        if ((attempt >= attempts)); then
            ((quiet)) || echo "retry: '$1' failed after $attempt attempt(s) (exit $status)" >&2
            return "$status"
        fi

        ((quiet)) || echo "retry: attempt $attempt/$attempts failed (exit $status), retrying in ${delay}s..." >&2
        sleep "$delay"
        delay=$((delay * factor))
        ((delay > max_delay)) && delay=$max_delay
    done
}

main "$@"

