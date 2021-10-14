#!/usr/bin/env bash

main() {

    working_dir="."

    if [ $# -eq 0 ]; then
        echo "You have to provide the number of commits to squash."
        echo "Optionally you can provide the branch name and the working dir."
        exit 1
    fi

    if [ $# -ge 1 ] && [ $# -le 3 ]; then
        n="$1"

        if  [ $# -eq 2 ]; then
            working_dir="$3"
            if [ ! -d "$working_dir" ]; then
                echo "$workind_dir is not a directory."
                exit 1
            fi
            cd "$working_dir"
        fi
        
        is_git_repo=$(git rev-parse --git-dir > /dev/null 2>&1)
        
        if [ ${#is_git_repo} -gt 0 ]; then
          echo "Not inside a git repo! Please provide a correct path."
          exit 1
        fi

        if  [ $# -eq 3 ]; then
            branch_name="$2"
            is_local_branch=$(git branch -l | grep -Fw $branch_name)
            
            if [ ${#is_local_branch} -eq 0 ]; then
                echo "provided branch doesn't exists"
                exit 1
            fi
        fi
    else
        echo "You can't specify more than 3 parameters!"
        exit 1
    fi

    git checkout "$branch_name"
    git reset --hard HEAD~$n
    git push -f origin "$branch_name"
}

main "$@"
