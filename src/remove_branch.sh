#!/usr/bin/env bash

main() {

    if [ $# -eq 0 ]; then
        echo "you have to provide the branch name!"
        exit 1
    elif [ $# -eq 1 ]; then
        branch_name="$1"
    else
        echo "currently not supported!"
        exit 1
    fi

    is_remote_branch=$(git branch -r | grep -Fw $branch_name > /dev/null)
    is_local_branch=$(git branch -l | grep -Fw $branch_name > /dev/null)

    if [ $is_remote_branch -ne 0 ] && [ $is_local_branch -ne 0 ]; then
        echo "provided branch doesn't exists"
        exit 1
    fi

    if [ $is_local_branch -eq 0 ]; then
        git push -d origin $branch_name
    fi

    if [ $is_remote_branch -eq 0 ]; then
        git branch -D $branch_name
    fi

}

main "$@"
