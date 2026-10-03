#!/usr/bin/env bash

# Script Name: random_int.sh
# Description: Generates a random integer within a specific range (inclusive),
#              with additional options. Uses bash's $RANDOM (not cryptographically
#              secure); the range may span at most 2^30 values.
#
# Usage: random_int.sh [options] lower_bound upper_bound
#
# Options:
#   -h, --help          Display this help message and exit.
#   -s, --seed VALUE    Seed the random number generator with the specified value.
#   -c, --count N       Generate N random numbers (default: 1).
#
# Arguments:
#   lower_bound         The smallest number that can be generated (may be negative).
#   upper_bound         The largest number that can be generated.
#
# Examples:
#   ./random_int.sh 1 10
#   ./random_int.sh --seed 42 1 100
#   ./random_int.sh --count 5 -10 20

set -euo pipefail

readonly MAX_RANGE=$((1 << 30))

function show_help() {
    # Print the header comment block (from "Script Name" up to the first non-comment line).
    sed -n '3,/^[^#]/{/^#/s/^# \{0,1\}//p}' "$0"
}

function die() {
    echo "Error: $*" >&2
    exit 1
}

function generate_random_integer() {
    local min="$1"
    local max="$2"
    local count="$3"
    local range=$((max - min + 1))
    # Largest multiple of range below MAX_RANGE; values above it are rejected to avoid modulo bias.
    local limit=$((MAX_RANGE - MAX_RANGE % range))
    local i rand

    for ((i = 0; i < count; i++)); do
        # Combine two 15-bit $RANDOM values into a 30-bit value.
        rand=$(((RANDOM << 15) | RANDOM))
        while ((rand >= limit)); do
            rand=$(((RANDOM << 15) | RANDOM))
        done
        echo $((rand % range + min))
    done
}

function main() {
    local seed=""
    local count=1

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -s|--seed)
                if [[ "${2:-}" =~ ^[0-9]+$ ]]; then
                    seed=$((10#$2))
                    shift 2
                else
                    die "--seed option requires a non-negative integer argument."
                fi
                ;;
            -c|--count)
                if [[ "${2:-}" =~ ^[0-9]+$ ]] && ((10#$2 > 0)); then
                    count=$((10#$2))
                    shift 2
                else
                    die "--count option requires a positive integer argument."
                fi
                ;;
            --)
                shift
                break
                ;;
            -[0-9]*)
                # A negative number: start of the positional arguments.
                break
                ;;
            -*)
                die "Unknown option: $1 (see --help)"
                ;;
            *)
                break
                ;;
        esac
    done

    # Check for the correct number of arguments
    if [[ $# -ne 2 ]]; then
        die "Must provide exactly two numbers for lower_bound and upper_bound (see --help)."
    fi

    local min="$1"
    local max="$2"

    # Validate that inputs are integers
    if ! [[ "$min" =~ ^-?[0-9]{1,18}$ ]]; then
        die "lower_bound '$min' is not an integer."
    fi

    if ! [[ "$max" =~ ^-?[0-9]{1,18}$ ]]; then
        die "upper_bound '$max' is not an integer."
    fi

    # Normalise (strip leading zeros so they aren't read as octal)
    min=$(( ${min%%[0-9]*}10#${min#-} ))
    max=$(( ${max%%[0-9]*}10#${max#-} ))

    if ((min > max)); then
        die "lower_bound cannot be greater than upper_bound."
    fi

    if ((max - min + 1 > MAX_RANGE)); then
        die "The range may contain at most $MAX_RANGE values."
    fi

    # Seed the random number generator if seed is provided
    if [[ -n "$seed" ]]; then
        RANDOM=$seed
    fi

    generate_random_integer "$min" "$max" "$count"
}

main "$@"

