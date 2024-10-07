#!/usr/bin/env bash

# Script Name: rand_int.sh
# Description: Generates a random integer within a specific range, with additional options.
#
# Usage: rand_int.sh [options] lower_bound upper_bound
#
# Options:
#   -h, --help          Display this help message and exit.
#   -s, --seed VALUE    Seed the random number generator with the specified value.
#   -c, --count N       Generate N random numbers (default: 1).
#
# Arguments:
#   lower_bound         The smallest number that can be generated.
#   upper_bound         The largest number that can be generated.
#
# Examples:
#   ./rand_int.sh 1 10
#   ./rand_int.sh --seed 42 1 100
#   ./rand_int.sh --count 5 10 20

set -euo pipefail

function show_help() {
    grep '^#' "$0" | cut -c 4-
    exit 0
}

function generate_random_integer() {
    local min="$1"
    local max="$2"
    local count="$3"

    if [[ "$min" -gt "$max" ]]; then
        echo "Error: lower_bound cannot be greater than upper_bound."
        exit 1
    fi

    local range=$((max - min + 1))

    for ((i = 0; i < count; i++)); do
        local rand=$((RANDOM % range + min))
        echo "$rand"
    done
}

function main() {
    # Default values
    SEED=""
    COUNT=1

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                ;;
            -s|--seed)
                if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                    SEED="$2"
                    shift 2
                else
                    echo "Error: --seed option requires a positive integer argument."
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
            -*)
                echo "Unknown option: $1"
                show_help
                ;;
            *)
                break
                ;;
        esac
    done

    # Check for the correct number of arguments
    if [[ $# -ne 2 ]]; then
        echo "Error: Must provide exactly two numbers for lower_bound and upper_bound."
        show_help
    fi

    local min="$1"
    local max="$2"

    # Validate that inputs are integers
    if ! [[ "$min" =~ ^-?[0-9]+$ ]]; then
        echo "Error: lower_bound '$min' is not an integer."
        exit 1
    fi

    if ! [[ "$max" =~ ^-?[0-9]+$ ]]; then
        echo "Error: upper_bound '$max' is not an integer."
        exit 1
    fi

    # Seed the random number generator if seed is provided
    if [[ -n "$SEED" ]]; then
        RANDOM="$SEED"
    fi

    generate_random_integer "$min" "$max" "$COUNT"
}

main "$@"
