#!/usr/bin/env bash

# Script Name: _run_all.sh
# Description: Runs every hook in this directory (symlinks not starting with _)
#              in check mode against the given paths, and exits with 1 if any
#              check failed. Works from any working directory.
# Usage: ./hooks/_run_all.sh [path...]
#        Paths are relative to the repository root (default: src tests).

set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root" || exit 1

if [[ $# -gt 0 ]]; then
    paths=("$@")
else
    paths=(src tests)
fi

if [[ -t 1 ]]; then
    RED=$'\e[31m'
    GREEN=$'\e[32m'
    RESET=$'\e[0m'
else
    RED=""
    GREEN=""
    RESET=""
fi

status=0
failed=()

mapfile -t hooks < <(find hooks -maxdepth 1 -type l -name '[^_]*.sh' | sort)
if [[ ${#hooks[@]} -eq 0 ]]; then
    echo "${RED}No hooks found in $repo_root/hooks${RESET}" >&2
    exit 1
fi

for path in "${paths[@]}"; do
    [[ -e $path ]] || continue
    for hook in "${hooks[@]}"; do
        echo -e "\nExecuting $hook on $path"
        if "$hook" --check "$path"; then
            echo "${GREEN}${hook} check on ${path} was successful${RESET}"
        else
            echo "${RED}${hook} check on ${path} failed${RESET}"
            failed+=("$hook ($path)")
            status=1
        fi
    done
done

if [[ $status -ne 0 ]]; then
    echo -e "\n${RED}Failed checks:${RESET}"
    printf '  %s\n' "${failed[@]}"
    echo "Run the failing hook without --check to fix the files, e.g. ./hooks/last_line_empty.sh src"
else
    echo -e "\n${GREEN}All checks passed.${RESET}"
fi

exit "$status"

