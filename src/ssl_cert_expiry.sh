#!/usr/bin/env bash

# Script Name: ssl_cert_expiry.sh
# Description: Checks when the TLS certificates of one or more hosts expire and
#              warns about the ones expiring soon. Suitable for cron: exits 1 if
#              any certificate expires within the warning window or cannot be read.
# Usage: ssl_cert_expiry.sh [-w days] [-t timeout] host[:port]...
# Options:
#   -w days     Warn when a certificate expires within this many days (default: 30).
#   -t timeout  Connection timeout in seconds (default: 10).
#   -h          Show this help message.
# Examples:
#   ssl_cert_expiry.sh github.com example.org
#   ssl_cert_expiry.sh -w 14 mail.example.com:465

set -uo pipefail

usage() {
    sed -n '3,/^$/p' "$0" | sed -e '/^$/d' -e 's/^# \{0,1\}//'
}

die() {
    echo "Error: $*" >&2
    exit 2
}

# Prints the certificate's notAfter date, or nothing on failure.
fetch_expiry() {
    local host="$1" port="$2" timeout_s="$3"
    timeout "$timeout_s" openssl s_client -connect "$host:$port" -servername "$host" </dev/null 2>/dev/null |
    openssl x509 -noout -enddate 2>/dev/null |
    cut -d= -f2
}

main() {
    local warn_days=30 timeout_s=10
    local opt

    while getopts ":w:t:h" opt; do
        case "$opt" in
            w) warn_days="$OPTARG" ;;
            t) timeout_s="$OPTARG" ;;
            h) usage; exit 0 ;;
            :) die "option -$OPTARG requires an argument" ;;
            *) die "unknown option -$OPTARG" ;;
        esac
    done
    shift $((OPTIND - 1))

    [[ $# -gt 0 ]] || { usage >&2; exit 2; }
    [[ $warn_days =~ ^[0-9]+$ ]] || die "days must be a non-negative integer"
    [[ $timeout_s =~ ^[1-9][0-9]*$ ]] || die "timeout must be a positive integer"
    command -v openssl >/dev/null 2>&1 || die "openssl is required"
    command -v timeout >/dev/null 2>&1 || die "'timeout' (coreutils) is required"

    local status=0 now target host port expiry expiry_ts days state
    now=$(date +%s)
    printf '%-40s %-26s %6s  %s\n' "HOST" "EXPIRES" "DAYS" "STATUS"

    for target in "$@"; do
        host="${target%%:*}"
        port=443
        [[ $target == *:* ]] && port="${target##*:}"

        expiry=$(fetch_expiry "$host" "$port" "$timeout_s")
        if [[ -z $expiry ]] || ! expiry_ts=$(date -d "$expiry" +%s 2>/dev/null); then
            printf '%-40s %-26s %6s  %s\n' "$host:$port" "-" "-" "ERROR (no certificate)"
            status=1
            continue
        fi

        days=$(((expiry_ts - now) / 86400))
        if ((expiry_ts <= now)); then
            state="EXPIRED"
            status=1
        elif ((days < warn_days)); then
            state="WARNING"
            status=1
        else
            state="OK"
        fi
        printf '%-40s %-26s %6s  %s\n' "$host:$port" "$(date -d "@$expiry_ts" '+%Y-%m-%d %H:%M %Z')" "$days" "$state"
    done

    exit "$status"
}

main "$@"

