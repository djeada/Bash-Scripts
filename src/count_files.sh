#!/usr/bin/env bash

main() {

    num_files_root=$(ls / | wc -l)
    num_files_home=$(ls ~/ | wc -l)

    echo "In root dir there are $num_files_root files and in home dir there are $num_files_home files."

}

main "$@"
