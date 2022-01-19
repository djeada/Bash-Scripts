#!/usr/bin/env bash

# Script Name: check_os.sh
# Description: Check the operating system of the current host
#              and print the result to the standard output.
# Usage: check_os.sh
# Example: ./check_os.sh

main() {

    if [ "$(uname)" == "Darwin" ]; then
        echo "Mac OS X platform detected"
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        distro=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
        echo "GNU/Linux platform platform detected"
        echo "Distro: $distro"
    elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
        echo "32 bits Windows NT platform detected"

    elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW64_NT" ]; then
        echo "64 bits Windows NT platform detected"
    else
        echo "unsupported platform detected"
    fi

}

main "$@"
