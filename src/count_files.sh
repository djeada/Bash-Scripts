#!/usr/bin/env bash

main() {

    num_files_root=$(ls / | wc -l)
    num_files_home=$(ls ~/ | wc -l)

    echo "There are $num_files_root files in the root directory and $num_files_home files in the home directory."

}

main "$@"
