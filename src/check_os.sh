#!/usr/bin/env bash

# Script Name: check_os.sh
# Description: Identifies the operating system of the current host
#              and outputs the result to the standard output.
# Usage: ./check_os.sh

main() {

    os_name=$(uname)

    case $os_name in
        Darwin)
            echo "Mac OS X platform detected"
            ;;
        Linux)
            distro=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
            echo "GNU/Linux platform detected"
            echo "Distro: $distro"
            ;;
        MINGW32_NT*)
            echo "32 bits Windows NT platform detected"
            ;;
        MINGW64_NT*)
            echo "64 bits Windows NT platform detected"
            ;;
        *)
            echo "Unsupported platform detected"
            ;;
    esac
}

main
