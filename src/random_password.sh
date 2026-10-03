#!/usr/bin/env bash

# Script Name: random_password.sh
# Description: Generates a random password with various customization options.
#              Randomness comes from /dev/urandom (unbiased, via rejection sampling).
#
# Usage: random_password.sh [options]
#
# Options:
#   -h, --help              Display this help message and exit.
#   -l, --length N          Specify the length of the password (default: 12).
#   -s, --special           Include special characters in the password.
#   -n, --numbers           Include numbers in the password.
#   -u, --uppercase         Include uppercase letters in the password.
#   -e, --exclude CHARS     Exclude specific characters from the password.
#   -c, --count N           Generate N passwords (default: 1).
#   -r, --repeat-allowed    Allow characters to be repeated (default).
#       --no-repeat         Do not repeat any character within a password.
#   Flags without a value can be combined, e.g. -snu.
#
# Examples:
#   ./random_password.sh --length 15 --special --numbers
#   ./random_password.sh -l 20 -snu -e 'oO0l1I' --count 5
#   ./random_password.sh --length 16 --no-repeat

set -euo pipefail

function show_help() {
    # Print the header comment block (from "Script Name" up to the first non-comment line).
    sed -n '3,/^[^#]/{/^#/s/^# \{0,1\}//p}' "$0"
}

function die() {
    echo "Error: $*" >&2
    exit 1
}

# Print a uniformly distributed random integer in [0, $1).
function random_below() {
    local n="$1" value
    local limit=$(( 4294967296 - 4294967296 % n ))
    while true; do
        value=$(od -An -N4 -tu4 /dev/urandom)
        value=${value//[[:space:]]/}
        if (( value < limit )); then
            echo $(( value % n ))
            return
        fi
    done
}

function generate_password() {
    local length="$1"
    local charset="$2"
    local repeat_allowed="$3"
    local password="" idx i

    if [ "${#charset}" -lt "$length" ] && [ "$repeat_allowed" = false ]; then
        die "Not enough unique characters in character set to generate a password of length $length without repeating characters."
    fi

    for (( i = 0; i < length; i++ )); do
        idx=$(random_below "${#charset}")
        password+="${charset:idx:1}"
        if [ "$repeat_allowed" = false ]; then
            # Remove the chosen character from the pool.
            charset="${charset:0:idx}${charset:idx+1}"
        fi
    done

    printf '%s\n' "$password"
}

function main() {
    # Default values
    local LENGTH=12
    local INCLUDE_SPECIAL=false
    local INCLUDE_NUMBERS=false
    local INCLUDE_UPPERCASE=false
    local EXCLUDE_CHARS=""
    local COUNT=1
    local REPEAT_ALLOWED=true

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -l|--length)
                if [[ "${2:-}" =~ ^[0-9]+$ ]] && (( 10#$2 > 0 )); then
                    LENGTH=$(( 10#$2 ))
                    shift 2
                else
                    die "--length option requires a positive integer argument."
                fi
                ;;
            -s|--special)
                INCLUDE_SPECIAL=true
                shift
                ;;
            -n|--numbers)
                INCLUDE_NUMBERS=true
                shift
                ;;
            -u|--uppercase)
                INCLUDE_UPPERCASE=true
                shift
                ;;
            -e|--exclude)
                if [[ -n "${2:-}" ]]; then
                    EXCLUDE_CHARS="$2"
                    shift 2
                else
                    die "--exclude option requires an argument."
                fi
                ;;
            -c|--count)
                if [[ "${2:-}" =~ ^[0-9]+$ ]] && (( 10#$2 > 0 )); then
                    COUNT=$(( 10#$2 ))
                    shift 2
                else
                    die "--count option requires a positive integer argument."
                fi
                ;;
            -r|--repeat-allowed)
                REPEAT_ALLOWED=true
                shift
                ;;
            --no-repeat)
                REPEAT_ALLOWED=false
                shift
                ;;
            -[snur][snur]*)
                # Split combined flags such as -snu into -s -n -u.
                if [[ "$1" =~ ^-[snur]+$ ]]; then
                    set -- "${1:0:2}" "-${1:2}" "${@:2}"
                else
                    die "Unknown option: $1 (see --help)"
                fi
                ;;
            *)
                die "Unknown option or argument: $1 (see --help)"
                ;;
        esac
    done

    # Build the character set
    local charset="abcdefghijklmnopqrstuvwxyz"
    if [ "$INCLUDE_UPPERCASE" = true ]; then
        charset+="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    fi
    if [ "$INCLUDE_NUMBERS" = true ]; then
        charset+="0123456789"
    fi
    if [ "$INCLUDE_SPECIAL" = true ]; then
        charset+='!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~'
    fi

    # Remove excluded characters (quoted so they are matched literally, not as globs)
    local i
    for (( i = 0; i < ${#EXCLUDE_CHARS}; i++ )); do
        charset="${charset//"${EXCLUDE_CHARS:i:1}"/}"
    done

    if [ -z "$charset" ]; then
        die "Character set is empty. Cannot generate password."
    fi

    # Generate passwords
    for (( i = 0; i < COUNT; i++ )); do
        generate_password "$LENGTH" "$charset" "$REPEAT_ALLOWED"
    done
}

main "$@"

