#!/usr/bin/env bash

# Script Name: count_files.sh
# Description: Counts the number of files in the root directory
# of the machine and home directory of the user.
# Usage: count_files.sh
# Example: ./count_files.sh

main() {

    num_files_root=$(ls / | wc -l)
    num_files_home=$(ls ~/ | wc -l)

    echo "There are $num_files_root files in the root directory and $num_files_home files in the home directory."

}

main "$@"

