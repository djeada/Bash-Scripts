#!/usr/bin/env bash

# Script Name: hello_world.sh
# Description: Demonstrates the use of echo command, environment variables, and command substitution.
# Usage: hello_world.sh
# Example: ./hello_world.sh

# Displaying a simple text string
echo "Hello, World!"

# Using command substitution to output the result of a command
# The $(pwd) command displays the current working directory
echo "I'm currently in: $(pwd)"

# Displaying the value of an environment variable
# HOME is an environment variable that stores the path of the home directory
echo "My home directory is: $HOME"

# Demonstrating that quotes aren't necessary to display the output of a command
# date command will output the current date and time
echo Here is the current date and time: "$(date)"

# Introducing a conditional statement
# Checking if the USER environment variable is set
if [[ -z "${USER}" ]]; then
    echo "The USER environment variable is not set."
else
    echo "The USER environment variable is set to: $USER"
fi

