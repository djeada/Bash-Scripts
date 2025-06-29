#!/usr/bin/env bash

# Script Name: adjust_volume.sh
# Description: Adjusts the volume for all available PulseAudio sinks.
#              The adjustment can be a percentage increase or decrease (e.g., +5%, -10%)
#              or a predefined mode (e.g., "full", "mute", "unmute", "reset").
# Usage: ./adjust_volume.sh -v [VALUE]
#        ./adjust_volume.sh -h
# Options:
#   -v [VALUE]   Adjust volume by a specific percentage or set to a specific mode.
#                Valid modes: full, mute, unmute, reset.
#   -h           Display this help message and exit.

# Predefined list of valid strings
VALID_STRINGS=("full" "mute" "unmute" "reset")

# Function to display help/usage information
display_help() {
    echo "Usage: $0 [OPTION] [VALUE]"
    echo
    echo "Options:"
    echo "  -v [VALUE]   Adjust volume by a specific amount (e.g., +5%, -10%) or set to a specific mode"
    echo "              Valid modes: ${VALID_STRINGS[*]}"
    echo "  -h           Display this help message and exit"
    echo
    exit 0
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

    # Check if input is a number with + or - and within the range of -100 to +100
    if [[ "$input" =~ ^[+-]?[0-9]+%?$ ]]; then
        local value="${input%?}" # Remove % if present
        if ((value >= -100 && value <= 100)); then
            return 0
        fi
    fi

    return 1
}

# Parse command-line arguments
while getopts ":v:h" opt; do
    case ${opt} in
        v)
            input_value="$OPTARG"
            ;;
        h)
            display_help
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            display_help
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            display_help
            ;;
    esac
done

# Validate the input
if ! validate_input "$input_value"; then
    echo "Invalid input: '$input_value'. Use -h for help." >&2
    exit 1
fi

# Apply the volume adjustment to all sinks
for sink in $(pactl list short sinks | cut -f1); do
    pactl set-sink-volume "$sink" "$input_value"
done

echo "Volume adjusted by $input_value for all sinks."

exit 0

