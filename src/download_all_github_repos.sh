#!/usr/bin/env bash
#
# Script Name: download_repos.sh
# Description: Retrieves a list of repositories from various sources (JSON file or GitHub API)
#              and clones them (optionally in parallel) before archiving them into a tar file.
#
# Usage:
#   download_repos.sh [--json-file file.json] [--user GITHUB_USER] [--token GITHUB_TOKEN]
#                     [--parallel N] [--output OUTPUT_TAR]
#
# Examples:
#   1) ./download_repos.sh --json-file repos.json
#   2) ./download_repos.sh --user myUser
#   3) ./download_repos.sh --user myUser --token myToken
#   4) ./download_repos.sh --user myUser --parallel 4
#
# Options:
#   --json-file FILE        Path to a JSON file containing a "repos" array of clone URLs.
#   --user GITHUB_USER      GitHub username to fetch repositories from (public or private with token).
#   --token GITHUB_TOKEN    GitHub personal access token (optional, required for private repos).
#   --parallel N            Number of parallel cloning jobs (default is 1 -> serial).
#   --output OUTPUT_TAR     Output filename for the resulting tar archive (default: repo_archive.tar).
#
# Requirements:
#   - git
#   - jq
#   - curl
#   - xargs (with -P) or parallel (optional, only if you want parallel downloads)
#
# ------------------------------------------------------------------------------

set -euo pipefail

###############################################################################
# Global variables (defaults)
###############################################################################
JSON_FILE=""
GITHUB_USER=""
GITHUB_TOKEN=""
PARALLEL_JOBS=1
OUTPUT_TAR="repo_archive.tar"

###############################################################################
# Functions
###############################################################################

print_usage() {
    cat <<EOF
Usage:
  $0 [--json-file file.json] [--user GITHUB_USER] [--token GITHUB_TOKEN]
     [--parallel N] [--output OUTPUT_TAR]

Examples:
  1) $0 --json-file repos.json
  2) $0 --user myUser
  3) $0 --user myUser --token myToken
  4) $0 --user myUser --parallel 4

Options:
  --json-file FILE        Path to a JSON file containing a "repos" array of clone URLs.
  --user GITHUB_USER      GitHub username to fetch repositories from (public or private with token).
  --token GITHUB_TOKEN    GitHub personal access token (optional, required for private repos).
  --parallel N            Number of parallel cloning jobs (default is 1 -> serial).
  --output OUTPUT_TAR     Output filename for the resulting tar archive (default: repo_archive.tar).
EOF
}

# -----------------------------------------------------------------------------
# check_dependencies: Verify that required commands are installed
# -----------------------------------------------------------------------------
check_dependencies() {
    local deps=("git" "curl" "jq" "tar")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            echo "Error: '$dep' is not installed or not in PATH."
            exit 1
        fi
    done

    # Check if parallel jobs > 1 is requested; see if xargs -P or parallel is installed
    if [[ "$PARALLEL_JOBS" -gt 1 ]]; then
        if ! xargs -P2 --help &>/dev/null && ! command -v parallel &>/dev/null; then
            echo "Warning: Parallel downloads requested, but 'xargs -P' or 'parallel' not supported."
            echo "Falling back to serial cloning (PARALLEL_JOBS=1)."
            PARALLEL_JOBS=1
        fi
    fi
}

# -----------------------------------------------------------------------------
# parse_args: Parse command-line arguments
# -----------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json-file)
                JSON_FILE="$2"
                shift 2
                ;;
            --user)
                GITHUB_USER="$2"
                shift 2
                ;;
            --token)
                GITHUB_TOKEN="$2"
                shift 2
                ;;
            --parallel)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            --output)
                OUTPUT_TAR="$2"
                shift 2
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                echo "Unknown argument: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    # Validate that at least one source is provided
    if [[ -z "$JSON_FILE" && -z "$GITHUB_USER" ]]; then
        echo "Error: You must specify either --json-file or --user."
        print_usage
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# retrieve_repos_from_json: Extract repository clone URLs from a JSON file
# -----------------------------------------------------------------------------
retrieve_repos_from_json() {
    if [[ ! -f "$JSON_FILE" ]]; then
        echo "Error: JSON file '$JSON_FILE' does not exist."
        exit 1
    fi

    # Expecting a structure like { "repos": ["https://...", "https://..."] }
    jq -r '.repos[]' "$JSON_FILE"
}

# -----------------------------------------------------------------------------
# retrieve_repos_from_github_api: Use GitHub API to fetch user repos (public or private)
# -----------------------------------------------------------------------------
retrieve_repos_from_github_api() {
    local user="$1"
    local token="$2"

    local auth_header=()
    if [[ -n "$token" ]]; then
        auth_header=(-H "Authorization: token $token")
    fi

    # We handle multiple pages if user has more than 100 repos:
    # We'll collect all pages until we get an empty list.
    local page=1
    local per_page=100
    local repos=()

    while true; do
        local url="https://api.github.com/users/${user}/repos?per_page=${per_page}&page=${page}"
        local response
        response="$(curl -s "${auth_header[@]}" "$url")"

        # If the response is empty or not an array, break
        if [[ -z "$response" || "$(echo "$response" | jq '. | type' 2>/dev/null)" != '"array"' ]]; then
            break
        fi

        # Check how many items
        local count
        count="$(echo "$response" | jq 'length')"
        if [[ "$count" -eq 0 ]]; then
            break
        fi

        # Extract clone_urls
        while IFS= read -r repo_url; do
            repos+=("$repo_url")
        done < <(echo "$response" | jq -r '.[].clone_url')

        ((page++))
    done

    if [[ ${#repos[@]} -eq 0 ]]; then
        echo "Warning: No repositories found for user '${user}'."
    fi

    # Print each repo on a new line
    printf "%s\n" "${repos[@]}"
}

# -----------------------------------------------------------------------------
# download_repos: Clone a list of repositories (serial or parallel)
# -----------------------------------------------------------------------------
download_repos() {
    local repo_list=("$@")
    local total="${#repo_list[@]}"

    echo "Cloning ${total} repositories..."

    # If PARALLEL_JOBS == 1, clone serially
    if [[ "$PARALLEL_JOBS" -le 1 ]]; then
        for repo in "${repo_list[@]}"; do
            echo "Cloning: $repo"
            git clone "$repo"
        done
    else
        # Attempt parallel clone using xargs -P or parallel
        # We'll feed the repo list into either xargs or parallel
        echo "Using parallel cloning with $PARALLEL_JOBS concurrent jobs..."

        # Prefer xargs approach if available
        if xargs -P2 --help &>/dev/null; then
            printf "%s\n" "${repo_list[@]}" | xargs -I {} -P "$PARALLEL_JOBS" bash -c 'git clone "$@"' _ {}
        else
            # fallback to parallel if xargs -P is not available
            parallel -j "$PARALLEL_JOBS" git clone ::: "${repo_list[@]}"
        fi
    fi
}

# -----------------------------------------------------------------------------
# create_archive: Tar the downloaded repositories
# -----------------------------------------------------------------------------
create_archive() {
    local temp_dir="$1"
    local output_file="$2"

    echo "Creating tar archive: $output_file"
    tar -cvf "$output_file" -C "$temp_dir" .
}

###############################################################################
# Main logic
###############################################################################

main() {
    parse_args "$@"
    check_dependencies

    # Create a temporary directory to store clones
    local temp_dir
    temp_dir="$(mktemp -d -t repo_archive_XXXXXX)"
    echo "Using temp directory: $temp_dir"

    # Fetch the list of repositories
    local repos=()
    if [[ -n "$JSON_FILE" ]]; then
        # From JSON file
        mapfile -t repos < <(retrieve_repos_from_json)
    elif [[ -n "$GITHUB_USER" ]]; then
        # From GitHub API
        mapfile -t repos < <(retrieve_repos_from_github_api "$GITHUB_USER" "$GITHUB_TOKEN")
    fi

    # If no repos found, exit
    if [[ "${#repos[@]}" -eq 0 ]]; then
        echo "No repositories to clone. Exiting."
        rm -rf "$temp_dir"
        exit 0
    fi

    # Clone them into temp_dir
    pushd "$temp_dir" >/dev/null
    download_repos "${repos[@]}"
    popd >/dev/null

    # Create archive
    create_archive "$temp_dir" "$OUTPUT_TAR"

    # Cleanup
    rm -rf "$temp_dir"

    echo "All repositories have been archived into: $OUTPUT_TAR"
}

main "$@"

