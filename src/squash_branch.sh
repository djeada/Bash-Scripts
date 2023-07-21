#!/usr/bin/env bash

# Script Name: squash_branch.sh
# Description: This script squashes all commits on a specified Git branch into a single commit.
# Usage: squash_branch.sh <branch-name>
# Example: squash_branch.sh dev

# Check if a branch name was provided
if [ $# -eq 0 ]; then
    echo "Error: No branch name provided."
    exit 1
fi

# Check out the specified branch
git checkout "$1"

# Get the number of commits on the branch
num_commits=$(git rev-list HEAD --count)

# Squash all commits on the branch into a single commit
git rebase -i HEAD~"$num_commits"

