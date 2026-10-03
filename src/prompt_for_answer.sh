#!/usr/bin/env bash

# Script Name: prompt_for_answer.sh
# Description: Asks a question and gets a user's response, falling back to a
#              default answer when the user just presses Enter.
# Usage: prompt_for_answer.sh
# Example: ./prompt_for_answer.sh

ask_question_and_get_response() {
    # $1 is the question
    # $2 is the default answer (optional)

    # Check the number of arguments
    if [ $# -eq 0 ]; then
        echo "No arguments supplied" >&2
        exit 1
    fi

    echo "$1"
    if [ $# -ge 2 ]; then
        read -rp "[$2] " response
        response="${response:-$2}"
    else
        read -rp "> " response
    fi
}

print_greeting() {
    echo "Hello $response"
}

main() {
    ask_question_and_get_response "What is your name?" "stranger"
    print_greeting
}

main "$@"

