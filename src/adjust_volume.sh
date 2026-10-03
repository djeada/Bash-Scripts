#!/usr/bin/env bash

# Script Name: adjust_volume.sh
# Description: Adjusts the volume for all available PulseAudio/PipeWire sinks (via pactl).
#              The adjustment can be relative (e.g., +5%, -10%), absolute (e.g., 50%)
#              or a predefined mode: full (100%), mute, unmute, reset (unmute and set 100%).
# Usage: ./adjust_volume.sh -v VALUE
#        ./adjust_volume.sh -h
# Options:
#   -v VALUE     Adjust volume by a specific percentage or set to a specific mode.
#                Valid modes: full, mute, unmute, reset.
#   -h           Display this help message and exit.

# Predefined list of valid strings
VALID_STRINGS=("full" "mute" "unmute" "reset")

# Function to display help/usage information
display_help() {
    echo "Usage: $0 -v VALUE"
    echo
    echo "Options:"
    echo "  -v VALUE     Change volume relatively (e.g., +5%, -10%), set it absolutely (e.g., 50%)"
    echo "               or apply a mode: full (100%), mute, unmute, reset (unmute + 100%)"
    echo "  -h           Display this help message and exit"
}

# Function to validate volume adjustment input
validate_input() {
    local input="$1"

    # Check if input is a valid string from the list
    for str in "${VALID_STRINGS[@]}"; do
        if [[ "$input" == "$str" ]]; then
            return 0
        fi
    done

    # Check if input is a number with optional + or - and within the range of -100 to +100
    if [[ "$input" =~ ^[+-]?[0-9]+%?$ ]]; then
        local value="${input%\%}" # Remove % if present
        if (( 10#${value#[+-]} <= 100 )); then
            return 0
        fi
    fi

    return 1
}

# Parse command-line arguments
input_value=""
while getopts ":v:h" opt; do
    case ${opt} in
        v)
            input_value="$OPTARG"
            ;;
        h)
            display_help
            exit 0
            ;;
        "?")
            echo "Invalid option: -$OPTARG" >&2
            display_help >&2
            exit 1
            ;;
        ":")
            echo "Option -$OPTARG requires an argument." >&2
            display_help >&2
            exit 1
            ;;
    esac
done

if [[ -z "$input_value" ]]; then
    display_help >&2
    exit 1
fi

# Validate the input
if ! validate_input "$input_value"; then
    echo "Invalid input: '$input_value'. Use -h for help." >&2
    exit 1
fi

if ! command -v pactl >/dev/null 2>&1; then
    echo "Error: pactl is not installed." >&2
    exit 1
fi

mapfile -t sinks < <(pactl list short sinks | cut -f1)
if [[ ${#sinks[@]} -eq 0 ]]; then
    echo "Error: No audio sinks found." >&2
    exit 1
fi

# Apply the volume adjustment to all sinks
status=0
for sink in "${sinks[@]}"; do
    # Numbers get a % suffix: without it pactl treats them as raw volume values
    case "$input_value" in
        full) pactl set-sink-volume "$sink" 100% ;;
        mute) pactl set-sink-mute "$sink" 1 ;;
        unmute) pactl set-sink-mute "$sink" 0 ;;
        reset) pactl set-sink-mute "$sink" 0 && pactl set-sink-volume "$sink" 100% ;;
        *) pactl set-sink-volume "$sink" "${input_value%\%}%" ;;
    esac || status=1
done

if [[ $status -ne 0 ]]; then
    echo "Error: Failed to adjust the volume of some sinks." >&2
    exit 1
fi

echo "Volume adjusted ($input_value) for all sinks."

