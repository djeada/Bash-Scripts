#!/usr/bin/env bash

main() {

    branch_name=$1
    git push -d origin $branch_name
    git branch -D $branch_name

}

main "$@"
