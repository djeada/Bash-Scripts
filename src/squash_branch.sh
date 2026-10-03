#!/usr/bin/env bash

# Script Name: squash_branch.sh
# Description: This script squashes all commits on a specified Git branch (its whole
#              history, down to the root commit) into a single commit. It opens an
#              interactive rebase: mark every commit except the first as "squash".
# Usage: squash_branch.sh <branch-name>
# Example: squash_branch.sh dev

# Check if a branch name was provided
if [ $# -ne 1 ]; then
    echo "Error: provide exactly one branch name." >&2
    echo "Usage: $0 <branch-name>" >&2
    exit 1
fi

# Check out the specified branch
if ! git checkout "$1"; then
    echo "Error: could not check out branch '$1'." >&2
    exit 1
fi

# Squash all commits on the branch into a single commit
# (HEAD~<commit count> does not exist, so rebase from the root instead).
git rebase -i --root

