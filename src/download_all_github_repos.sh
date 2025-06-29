#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Script Name: download_repos.sh
# Description:
#   Retrieve repositories from GitHub (user or organisation) **or** from a JSON
#   manifest and clone them – serially or in parallel – into a destination
#   directory. Optionally perform shallow or mirror clones, compress the result
#   into a tarball (gz|bz2|xz|none), and produce a SHA‑256 checksum. The script
#   is defensive, token‑aware, and cleans up after itself.
# ------------------------------------------------------------------------------
#
# Usage:
#   ./download_repos.sh [OPTIONS]
#
# Core sources (one required)
#   --json-file FILE           JSON file containing { "repos": [ clone_URL, … ] }
#   --user USERNAME            GitHub user to fetch repos from
#   --org ORGNAME              GitHub organisation to fetch repos from
#
# Authentication & network
#   --token TOKEN              GitHub Personal Access Token (PAT).
#                              If omitted the script falls back to $GITHUB_TOKEN
#                              env var. Using env vars avoids leaking secrets in
#                              process listings / shell history.
#   --protocol {https|ssh}     Force convert clone URLs to chosen protocol.
#                              Default: leave clone_url untouched.
#
# Clone behaviour
#   --shallow                  Clone with --depth 1 (history truncated).
#   --mirror                   Use git --mirror instead of regular clone.
#   --parallel N               Number of concurrent clone jobs (default 1).
#
# Output
#   --dest DIR                 Directory to place cloned repos before archiving.
#                              Default: a temporary dir that is auto‑removed.
#   --output FILE.tar[.*]      Name of resulting archive (default repo_archive.tar.gz).
#   --compression {gz|bz2|xz|none}
#                              Compression algorithm for tarball (default gz).
#
# Miscellaneous
#   --filter-forks {true|false}  Skip forks when using GitHub API (default false)
#   -h | --help                Show this help and exit.
#
# Examples:
#   ./download_repos.sh --json-file repos.json --shallow
#   ./download_repos.sh --user alice --parallel 4 --dest ./backup
#   GITHUB_TOKEN=*** ./download_repos.sh --org mycorp --compression xz
# ------------------------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

###############################################################################
# Global defaults
###############################################################################
JSON_FILE=""
GITHUB_USER=""
GITHUB_ORG=""
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
PROTOCOL=""
PARALLEL_JOBS=1
DEST_DIR=""
OUTPUT_TAR="repo_archive.tar.gz"
COMPRESSION="gz"
SHALLOW=false
MIRROR=false
FILTER_FORKS=false

###############################################################################
# Pretty printing helpers
###############################################################################
color() { local c=$1; shift; printf "\e[%sm%s\e[0m" "$c" "$*"; }
info()  { printf "[%s] %s\n" "$(color 34 INFO)"  "$*"; }
warn()  { printf "[%s] %s\n" "$(color 33 WARN)" "$*"; }
error() { printf "[%s] %s\n" "$(color 31 ERROR)" "$*" >&2; }

###############################################################################
print_usage() {
    sed -n '1,/^set -euo pipefail/p' "$0" | sed '1,6d' | sed '$d'
}

###############################################################################
# Dependency checks
###############################################################################
check_dependencies() {
    local deps=(git curl jq tar sha256sum)
    for dep in "${deps[@]}"; do
        command -v "$dep" &>/dev/null || { error "'$dep' is not installed."; exit 1; }
    done

    if (( PARALLEL_JOBS > 1 )); then
        if command -v parallel &>/dev/null; then
            CLONE_LAUNCHER="parallel -j $PARALLEL_JOBS"
        elif xargs --help 2>&1 | grep -q -- '-P'; then
            CLONE_LAUNCHER="xargs -n1 -P $PARALLEL_JOBS"
        else
            warn "Parallel cloning requested but neither GNU parallel nor xargs -P available. Falling back to serial.";
            PARALLEL_JOBS=1
        fi
    fi
}

###############################################################################
# Argument parsing
###############################################################################
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json-file)      JSON_FILE="$2"; shift 2;;
            --user)           GITHUB_USER="$2"; shift 2;;
            --org)            GITHUB_ORG="$2"; shift 2;;
            --token)          GITHUB_TOKEN="$2"; shift 2;;
            --protocol)       PROTOCOL="$2"; shift 2;;
            --parallel)       PARALLEL_JOBS="$2"; shift 2;;
            --dest)           DEST_DIR="$2"; shift 2;;
            --output)         OUTPUT_TAR="$2"; shift 2;;
            --compression)    COMPRESSION="$2"; shift 2;;
            --shallow)        SHALLOW=true; shift 1;;
            --mirror)         MIRROR=true; shift 1;;
            --filter-forks)   FILTER_FORKS=$(echo "$2" | tr '[:upper:]' '[:lower:]'); shift 2;;
            -h|--help)        print_usage; exit 0;;
            *) error "Unknown argument: $1"; print_usage; exit 1;;
        esac
    done

    # Source validation
    if [[ -z "$JSON_FILE" && -z "$GITHUB_USER" && -z "$GITHUB_ORG" ]]; then
        error "Specify --json-file, --user or --org."; exit 1;
    fi

    # Compression validation
    case "$COMPRESSION" in gz|bz2|xz|none) ;; *) error "Invalid --compression value."; exit 1;; esac

    # Parallel validation is numeric
    if ! [[ "$PARALLEL_JOBS" =~ ^[0-9]+$ ]]; then
        error "--parallel expects a positive integer"; exit 1;
    fi
}

###############################################################################
# Helpers
###############################################################################
convert_protocol() {
    local url="$1"
    if [[ -z "$PROTOCOL" ]]; then
        printf '%s' "$url"; return 0
    fi

    if [[ "$PROTOCOL" == "ssh" ]]; then
        # https://github.com/user/repo.git -> git@github.com:user/repo.git
        printf '%s' "$url" | sed -E 's#https://github.com/(.+)#git@github.com:\1#'
    else
        # git@github.com:user/repo.git -> https://github.com/user/repo.git
        printf '%s' "$url" | sed -E 's#git@github.com:(.+)#https://github.com/\1#'
    fi
}

build_git_clone_cmd() {
    local repo_url="$1"
    local flags=()
    $SHALLOW   && flags+=(--depth 1)
    $MIRROR    && flags+=(--mirror)
    printf 'git clone %s %q' "${flags[*]}" "${repo_url}"
}

###############################################################################
# Repo retrieval functions
###############################################################################
retrieve_repos_from_json() {
    [[ -f "$JSON_FILE" ]] || { error "JSON '$JSON_FILE' not found"; exit 1; }
    jq -r '.repos[]' "$JSON_FILE"
}

# Generic GitHub API fetcher supporting pagination via Link header
github_api_paged() {
    local url="$1"
    local token_header=()
    [[ -n "$GITHUB_TOKEN" ]] && token_header=(-H "Authorization: token $GITHUB_TOKEN")

    while [[ -n "$url" ]]; do
        # Fetch headers + body
        local response
        response=$(curl -sSL -H 'Accept: application/vnd.github+json' -D - "${token_header[@]}" "$url")
        local headers body
        headers="$(printf '%s\n' "$response" | sed -n '1,/^\r$/p')"
        body="$(printf '%s\n' "$response" | sed -n '/^\r$/{n;:a;n;ba}' )"

        # Rate‑limit handling
        if echo "$body" | jq -e '.message? | test("rate limit"; "i")' &>/dev/null; then
            error "GitHub API rate limit exceeded. Provide a valid token."; exit 1;
        fi

        printf '%s\n' "$body"

        # Parse next link
        local next
        next=$(printf '%s\n' "$headers" | grep -i '^Link:' | sed -E 's/.*, <([^>]+)>; rel="next".*/\1/')
        url="$next"
    done
}

retrieve_repos_from_github() {
    local endpoint=""
    if [[ -n "$GITHUB_USER" ]]; then
        endpoint="https://api.github.com/users/${GITHUB_USER}/repos?per_page=100&type=all"
    else
        endpoint="https://api.github.com/orgs/${GITHUB_ORG}/repos?per_page=100&type=all"
    fi

    github_api_paged "$endpoint" | jq -r \
        --argjson skipFork "$FILTER_FORKS" '
            map(select((.fork|not) or ($skipFork|not))) | .[].clone_url'
}

###############################################################################
# Clone repositories (serial or parallel)
###############################################################################
clone_repos() {
    local -a repos=("$@")
    local total=${#repos[@]}
    local idx=1

    info "Cloning ${total} repositories…"

    if (( PARALLEL_JOBS <= 1 )); then
        for repo in "${repos[@]}"; do
            local converted
            converted=$(convert_protocol "$repo")
            if [[ -d "$(basename "$converted" .git)" ]]; then
                warn "[${idx}/${total}] Skipping existing $(basename "$converted")"
            else
                info "[${idx}/${total}] Cloning $(basename "$converted")"
                eval $(build_git_clone_cmd "$converted")
            fi
            ((idx++))
        done
    else
        info "Using $PARALLEL_JOBS parallel jobs via ${CLONE_LAUNCHER%% *}."
        printf '%s\n' "${repos[@]}" | ${CLONE_LAUNCHER} bash -c '
            repo="$0";
            convert_protocol() {
                if [[ -z "${PROTOCOL}" ]]; then printf "%s" "$1"; else
                    if [[ "${PROTOCOL}" == "ssh" ]]; then
                        printf "%s" "$1" | sed -E "s#https://github.com/(.+)#git@github.com:\1#";
                    else
                        printf "%s" "$1" | sed -E "s#git@github.com:(.+)#https://github.com/\1#";
                    fi
                fi
            }
            converted=$(convert_protocol "$repo")
            dir=$(basename "$converted" .git)
            if [[ -d "$dir" ]]; then exit 0; fi
            eval $(build_git_clone_cmd "$converted")
        '
    fi
}

###############################################################################
# Archive helpers
###############################################################################
create_archive() {
    local src_dir="$1" out_file="$2" comp="$3"
    local flag=""
    case "$comp" in
        gz)  flag="z";;
        bz2) flag="j";;
        xz)  flag="J";;
        none) flag="";;
    esac
    info "Creating archive ${out_file} (compression: ${comp})"
    if [[ -n "$flag" ]]; then
        tar -c${flag}f "$out_file" -C "$src_dir" .
    else
        tar -cf "$out_file" -C "$src_dir" .
    fi
}

###############################################################################
# Main
###############################################################################
main() {
    parse_args "$@"
    check_dependencies

    # Prepare destination directory
    local is_temp=false
    if [[ -z "$DEST_DIR" ]]; then
        DEST_DIR=$(mktemp -d -t repo_archive_XXXXXX)
        is_temp=true
    else
        mkdir -p "$DEST_DIR"
    fi
    info "Using destination directory: $DEST_DIR"

    # Ensure cleanup on EXIT / INT / TERM if temp dir
    $is_temp && trap 'rm -rf "$DEST_DIR"' EXIT INT TERM

    # Retrieve repo list
    mapfile -t REPOS < <(
        if [[ -n "$JSON_FILE" ]]; then retrieve_repos_from_json;
        else retrieve_repos_from_github; fi )

    if (( ${#REPOS[@]} == 0 )); then
        warn "No repositories found. Exiting."
        exit 0
    fi

    pushd "$DEST_DIR" >/dev/null
    clone_repos "${REPOS[@]}"
    popd >/dev/null

    create_archive "$DEST_DIR" "$OUTPUT_TAR" "$COMPRESSION"
    sha256sum "$OUTPUT_TAR" > "$OUTPUT_TAR.sha256"
    info "SHA‑256 checksum written to $OUTPUT_TAR.sha256"

    if $is_temp; then
        info "Removing temporary directory $DEST_DIR"
        rm -rf "$DEST_DIR"
    fi

    info "All repositories archived into: $OUTPUT_TAR"
}

main "$@"
