#!/usr/bin/env bash

# Script Name: random_password.sh
# Description: Generates a random password with various customization options.
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
#   -r, --repeat-allowed    Allow characters to be repeated (default: true).
#
# Examples:
#   ./random_password.sh --length 15 --special --numbers
#   ./random_password.sh -l 20 -snu -e 'oO0l1I' --count 5
#   ./random_password.sh --length 16 --no-repeat

set -euo pipefail

function show_help() {
    grep '^#' "$0" | cut -c 4-
    exit 0
}

function generate_password() {
    local length="$1"
    local charset="$2"
    local repeat_allowed="$3"

    if [ -z "$charset" ]; then
        echo "Error: Character set is empty. Cannot generate password."
        exit 1
    fi

    if [ "${#charset}" -lt "$length" ] && [ "$repeat_allowed" = false ]; then
        echo "Error: Not enough unique characters in character set to generate a password of length $length without repeating characters."
        exit 1
    fi

    local password=""
    if [ "$repeat_allowed" = true ]; then
        password=$(LC_ALL=C tr -dc "$charset" </dev/urandom | head -c "$length")
    else
        password=$(LC_ALL=C echo "$charset" | fold -w1 | shuf | tr -d '\n' | head -c "$length")
    fi

    echo "$password"
}

function main() {
    # Default values
    LENGTH=12
    INCLUDE_SPECIAL=false
    INCLUDE_NUMBERS=false
    INCLUDE_UPPERCASE=false
    EXCLUDE_CHARS=""
    COUNT=1
    REPEAT_ALLOWED=true

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                ;;
            -l|--length)
                if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ && "$2" -gt 0 ]]; then
                    LENGTH="$2"
                    shift 2
                else
                    echo "Error: --length option requires a positive integer argument."
                    exit 1
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
                    echo "Error: --exclude option requires an argument."
                    exit 1
                fi
                ;;
            -c|--count)
                if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ && "$2" -gt 0 ]]; then
                    COUNT="$2"
                    shift 2
                else
                    echo "Error: --count option requires a positive integer argument."
                    exit 1
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
            -*)
                echo "Unknown option: $1"
                show_help
                ;;
            *)
                echo "Unknown argument: $1"
                show_help
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
        charset+="!\"#\$%&'()*+,-./:;<=>?@[\]^_\`{|}~"
    fi

    # Remove excluded characters
    if [ -n "$EXCLUDE_CHARS" ]; then
        for (( i=0; i<${#EXCLUDE_CHARS}; i++ )); do
            charset="${charset//${EXCLUDE_CHARS:i:1}/}"
        done
    fi

    # Generate passwords
    for (( i=0; i<COUNT; i++ )); do
        generate_password "$LENGTH" "$charset" "$REPEAT_ALLOWED"
    done
}

main "$@"
