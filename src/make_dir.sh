#!/usr/bin/env bash

main() {

    echo "Enter a directory name:"

    read dir_name

    if [-d "$dir_name" ]
    then
        echo "Directory already exists!"
    else
        `mkdir $dir_name`
        echo "Directory has been created!"
    fi

}

main "$@"
