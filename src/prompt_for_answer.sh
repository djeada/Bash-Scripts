#!/usr/bin/env bash

# Script Name: promt_for_answer.sh
# Description: Asks a question and gets a user's response.
# Usage: prompt_for_answer.sh
# Example: ./prompt_for_answer.sh

ask_question_and_get_response() {
    # $1 is the question
    # $2 is the default answer

    # Check the number of arguments
    if [ $# -eq 0 ]; then
        echo "No arguments supplied"
        exit 1
    fi

    echo -e "$1"
    read -rp "[$2]"$'\n' response

    if [ $# -eq 2 ]; then
        if [ -z "$response" ]; then
            response="$2"
        fi
    fi
}

print_greeting() {
    echo "Hello $response"
}

main() {
    ask_question_and_get_response "What is your name?"
    print_greeting
}

main "$@"

