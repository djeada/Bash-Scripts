#!/usr/bin/env bash

# Script Name: git_cleanup_branches.sh
# Description: Deletes local branches that are already merged into the base
#              branch, and optionally branches whose upstream was deleted on the
#              remote ("gone"). The current branch and the base branch are never
#              touched. Shows what will be deleted and asks before doing it.
# Usage: git_cleanup_branches.sh [-b base] [-g] [-n] [-y]
# Options:
#   -b base  Branch to compare against (default: origin's HEAD, else main/master).
#   -g       Also delete branches whose upstream is gone (requires a fetch, done
#            automatically with --prune). These are deleted with -D because a
#            squash-merged branch is not seen as merged by git.
#   -n       Dry run: only list the branches that would be deleted.
#   -y       Do not ask for confirmation.
#   -h       Show this help message.
# Examples:
#   git_cleanup_branches.sh -n
#   git_cleanup_branches.sh -g -b develop

set -euo pipefail

usage() {
    sed -n '3,/^$/p' "$0" | sed -e '/^$/d' -e 's/^# \{0,1\}//'
}

die() {
    echo "Error: $*" >&2
    exit 1
}

detect_base() {
    local ref
    if ref=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null); then
        echo "${ref#origin/}"
        return
    fi
    for ref in main master; do
        if git show-ref --verify --quiet "refs/heads/$ref"; then
            echo "$ref"
            return
        fi
    done
    die "could not detect the base branch, pass it with -b"
}

main() {
    local base="" gone=0 dry_run=0 assume_yes=0
    local opt

    while getopts ":b:gnyh" opt; do
        case "$opt" in
            b) base="$OPTARG" ;;
            g) gone=1 ;;
            n) dry_run=1 ;;
            y) assume_yes=1 ;;
            h) usage; exit 0 ;;
            :) die "option -$OPTARG requires an argument" ;;
            *) die "unknown option -$OPTARG" ;;
        esac
    done

    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository"
    [[ -n $base ]] || base=$(detect_base)
    git rev-parse --verify --quiet "$base^{commit}" >/dev/null || die "base branch '$base' does not exist"

    local current
    current=$(git branch --show-current)

    if ((gone)); then
        git fetch --all --prune --quiet || echo "Warning: fetch failed, using cached remote state." >&2
    fi

    local -a merged=() orphaned=()
    local branch track
    while IFS= read -r branch; do
        [[ $branch == "$current" || $branch == "$base" ]] && continue
        merged+=("$branch")
    done < <(git for-each-ref --format='%(refname:short)' --merged "$base" refs/heads/)

    if ((gone)); then
        while IFS=$'\t' read -r branch track; do
            [[ $track == "[gone]" ]] || continue
            [[ $branch == "$current" || $branch == "$base" ]] && continue
            [[ " ${merged[*]} " == *" $branch "* ]] && continue
            orphaned+=("$branch")
        done < <(git for-each-ref --format=$'%(refname:short)\t%(upstream:track)' refs/heads/)
    fi

    if ((${#merged[@]} + ${#orphaned[@]} == 0)); then
        echo "Nothing to clean up (base: $base)."
        return 0
    fi

    ((${#merged[@]})) && printf 'Merged into %s:\n' "$base" && printf '  %s\n' "${merged[@]}"
    ((${#orphaned[@]})) && printf 'Upstream gone:\n' && printf '  %s\n' "${orphaned[@]}"

    if ((dry_run)); then
        echo "Dry run: nothing deleted."
        return 0
    fi

    if ((!assume_yes)); then
        local answer
        read -r -p "Delete these branches? [y/N] " answer
        [[ $answer =~ ^[Yy]([Ee][Ss])?$ ]] || { echo "Aborted."; return 1; }
    fi

    ((${#merged[@]})) && git branch -d -- "${merged[@]}"
    ((${#orphaned[@]})) && git branch -D -- "${orphaned[@]}"
    return 0
}

main "$@"

