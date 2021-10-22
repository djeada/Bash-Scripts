#!/usr/bin/env bash

main() {

    echo "Enter the directory name:"

    read dir_name

    if [ -d "$dir_name" ]
    then
        echo "There is already a directory with that name!"
    else
        mkdir "$dir_name"
        echo "A directory has been created!"
    fi

}

main "$@"
