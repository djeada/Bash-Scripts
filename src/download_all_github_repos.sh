#!/usr/bin/env bash

# Script Name: download_all_github_repos.sh
# Description: Discovers GitHub repositories into an editable manifest, then
#              backs up the enabled repositories from that manifest. Supports
#              JSON/CSV manifests, HTTPS or SSH clones, mirror/clone/archive/
#              sparse backup modes, resumable runs, retries, rate-limit waits,
#              cron-friendly logging, and checksums for downloaded archives.
# Usage:
#   ./download_all_github_repos.sh discover [OPTIONS]
#   ./download_all_github_repos.sh backup [OPTIONS]
#   ./download_all_github_repos.sh validate-manifest --manifest FILE
#   ./download_all_github_repos.sh convert-manifest --manifest FILE --output FILE --format json|csv
#
# Discovery examples:
#   ./download_all_github_repos.sh discover --user alice --output repos.json
#   ./download_all_github_repos.sh discover --org my-org --token "$GITHUB_TOKEN" --output repos.csv --format csv
#   ./download_all_github_repos.sh discover --authenticated-user --token "$GITHUB_TOKEN" --output repos.json
#
# Backup examples:
#   ./download_all_github_repos.sh backup --manifest repos.json --dest ~/github-backups
#   ./download_all_github_repos.sh backup --manifest repos.json --dest ~/github-backups --resume
#   ./download_all_github_repos.sh backup --manifest repos.json --dest ~/github-backups --mode archive
#   ./download_all_github_repos.sh backup --manifest repos.json --dest /backups/github --non-interactive --log-file /var/log/github-backup.log

set -euo pipefail
IFS=$'\n\t'

###############################################################################
# Global defaults
###############################################################################
SCRIPT_NAME="$(basename "$0")"
COMMAND=""

GITHUB_USER=""
GITHUB_ORG=""
AUTHENTICATED_USER=false
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
VISIBILITY="all"

MANIFEST=""
INPUT_MANIFEST=""
OUTPUT_FILE=""
OUTPUT_FORMAT="json"
DEST_DIR=""
RUN_DIR=""
STATE_FILE=""
LOCK_FILE=""
CONFIG_FILE=""

DISCOVER_INCLUDE_FORKS=true
DISCOVER_INCLUDE_ARCHIVED=true
NAME_REGEX=""
MAX_REPOS=""

BACKUP_MODE=""
PROTOCOL="https"
RESUME=false
NON_INTERACTIVE=false
CHECKSUM=true
VERIFY_AFTER_BACKUP=false
PARALLEL_JOBS=1

RATE_LIMIT_MODE="wait"
SLEEP_BETWEEN_REPOS=0
MAX_RETRIES=3
RETRY_DELAY=5
RETRY_BACKOFF=2

QUIET=false
VERBOSE=false
NO_COLOR=false
LOG_FILE=""

STATE_MANIFEST_CHECKSUM=""
GITHUB_NEXT_URL=""
DISCOVER_ENDPOINT=""
DISCOVER_SOURCE_TYPE=""
DISCOVER_SOURCE_VALUE=""

###############################################################################
# Usage
###############################################################################
print_usage() {
    cat <<'USAGE'
Usage:
  download_all_github_repos.sh discover [OPTIONS]
  download_all_github_repos.sh backup [OPTIONS]
  download_all_github_repos.sh validate-manifest --manifest FILE
  download_all_github_repos.sh convert-manifest --manifest FILE --output FILE --format json|csv

Discovery examples:
  download_all_github_repos.sh discover --user alice --output repos.json
  download_all_github_repos.sh discover --org my-org --token "$GITHUB_TOKEN" --output repos.csv --format csv
  download_all_github_repos.sh discover --authenticated-user --token "$GITHUB_TOKEN" --output repos.json

Backup examples:
  download_all_github_repos.sh backup --manifest repos.json --dest ~/github-backups
  download_all_github_repos.sh backup --manifest repos.json --dest ~/github-backups --resume
  download_all_github_repos.sh backup --manifest repos.json --dest ~/github-backups --mode archive
  download_all_github_repos.sh backup --manifest repos.json --dest /backups/github --non-interactive --log-file /var/log/github-backup.log

Use "discover --help" or "backup --help" for command-specific options.
USAGE
}

print_discover_usage() {
    cat <<'USAGE'
Usage: download_all_github_repos.sh discover [OPTIONS]

Source options:
  --user USER                 Discover repositories for a GitHub user.
  --org ORG                   Discover repositories for a GitHub organization.
  --authenticated-user        Discover repositories visible to the token owner.
  --token TOKEN               GitHub token. Defaults to GITHUB_TOKEN.

Manifest options:
  --output FILE               Manifest path to write. Required.
  --format json|csv           Output manifest format. Default: json.
  --input FILE                Existing manifest to refresh while preserving user edits.
  --config FILE               Load defaults from a JSON config file. CLI flags override.

Filters:
  --include-forks             Include forked repositories. Default.
  --exclude-forks             Exclude forked repositories.
  --include-archived          Include archived repositories. Default.
  --exclude-archived          Exclude archived repositories.
  --visibility all|public|private
  --name-regex REGEX          Keep only full_name values matching REGEX.
  --max-repos N               Keep only the first N repositories after filtering.

Reliability/logging:
  --rate-limit wait|fail      Wait for GitHub rate-limit reset or fail. Default: wait.
  --max-retries N             Retry failed API calls. Default: 3.
  --retry-delay SECONDS       Initial retry delay. Default: 5.
  --log-file FILE             Append logs to FILE.
  --quiet                     Suppress informational logs.
  --verbose                   Print extra diagnostics.
  --no-color                  Disable colored log labels.
USAGE
}

print_backup_usage() {
    cat <<'USAGE'
Usage: download_all_github_repos.sh backup [OPTIONS]

Required:
  --manifest FILE             JSON or CSV manifest created by discover.
  --dest DIR                  Backup destination root.
  --config FILE               Load defaults from a JSON config file. CLI flags override.

Backup behavior:
  --mode mirror|clone|archive|sparse
                              Override per-repository manifest mode.
  --protocol https|ssh        Clone protocol for git modes. Default: https.
  --token TOKEN               GitHub token. Defaults to GITHUB_TOKEN.
  --resume                    Reuse state and skip completed repositories.
  --checksum                  Write checksums for archive files. Default.
  --no-checksum               Disable archive checksums.
  --verify-after-backup       Run lightweight validation after each backup.
  --sleep SECONDS             Sleep between repositories.
  --parallel N                Accepted for compatibility. Stateful backup runs serially.

Cron/logging:
  --non-interactive           Do not prompt. Current implementation never prompts.
  --log-file FILE             Append logs to FILE.
  --lock-file FILE            Prevent overlapping runs. Defaults under --dest.
  --state-file FILE           Resume/status file. Defaults under --dest.
  --quiet                     Suppress informational logs.
  --verbose                   Print extra diagnostics.
  --no-color                  Disable colored log labels.

Reliability:
  --rate-limit wait|fail      Wait for GitHub rate-limit reset or fail. Default: wait.
  --max-retries N             Retry failed repo backups. Default: 3.
  --retry-delay SECONDS       Initial retry delay. Default: 5.
  --retry-backoff N           Retry delay multiplier. Default: 2.
USAGE
}

###############################################################################
# Logging
###############################################################################
supports_color() {
    [[ "$NO_COLOR" != true && -t 2 ]]
}

color_code() {
    case "$1" in
        INFO) printf '34' ;;
        WARN) printf '33' ;;
        ERROR) printf '31' ;;
        DEBUG) printf '36' ;;
        *) printf '0' ;;
    esac
}

log_msg() {
    local level="$1"
    shift
    local message="$*"
    local timestamp label rendered plain

    [[ "$QUIET" == true && "$level" == "INFO" ]] && return 0
    [[ "$VERBOSE" != true && "$level" == "DEBUG" ]] && return 0

    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    plain="[$timestamp] [$level] $message"

    if supports_color; then
        label="$(printf '\e[%sm%s\e[0m' "$(color_code "$level")" "$level")"
        rendered="[$timestamp] [$label] $message"
    else
        rendered="$plain"
    fi

    printf '%s\n' "$rendered" >&2
    if [[ -n "$LOG_FILE" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")"
        printf '%s\n' "$plain" >> "$LOG_FILE"
    fi
}

info() { log_msg INFO "$@"; }
warn() { log_msg WARN "$@"; }
error() { log_msg ERROR "$@"; }
debug() { log_msg DEBUG "$@"; }

die() {
    error "$*"
    exit 1
}

###############################################################################
# Generic helpers
###############################################################################
require_command() {
    local dep="$1"
    command -v "$dep" >/dev/null 2>&1 || die "'$dep' is not installed."
}

check_common_dependencies() {
    require_command jq
    require_command curl
    require_command date
    require_command sed
    require_command sha256sum
}

check_backup_dependencies() {
    check_common_dependencies
    require_command git
    require_command tar
    if [[ -n "$LOCK_FILE" ]]; then
        require_command flock
    fi
}

is_positive_integer() {
    [[ "$1" =~ ^[0-9]+$ ]] && (( "$1" > 0 ))
}

is_non_negative_integer() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

now_utc_compact() {
    date -u +"%Y%m%dT%H%M%SZ"
}

now_utc_iso() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

json_string_array_from_semicolon() {
    local value="$1"
    jq -cn --arg value "$value" '$value | split(";") | map(select(length > 0))'
}

config_arg_from_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --config)
                printf '%s' "${2:-}"
                return 0
                ;;
            *)
                shift
                ;;
        esac
    done
}

config_string() {
    local filter="$1"
    jq -r "$filter // empty" "$CONFIG_FILE"
}

set_config_string() {
    local var_name="$1"
    local filter="$2"
    local value
    value="$(config_string "$filter")"
    if [[ -n "$value" ]]; then
        printf -v "$var_name" '%s' "$value"
    fi
    return 0
}

set_config_bool() {
    local var_name="$1"
    local filter="$2"
    local value
    value="$(config_string "$filter")"
    case "$value" in
        true|false) printf -v "$var_name" '%s' "$value" ;;
        "") ;;
        *) die "Config value for $filter must be true or false." ;;
    esac
    return 0
}

load_discover_config() {
    set_config_string GITHUB_USER '.user'
    set_config_string GITHUB_ORG '.org'
    set_config_bool AUTHENTICATED_USER '.authenticated_user'
    set_config_string GITHUB_TOKEN '.token'
    set_config_string OUTPUT_FILE '.output'
    set_config_string OUTPUT_FORMAT '.format'
    set_config_string INPUT_MANIFEST '.input'
    set_config_bool DISCOVER_INCLUDE_FORKS '.include_forks'
    set_config_bool DISCOVER_INCLUDE_ARCHIVED '.include_archived'
    set_config_string VISIBILITY '.visibility'
    set_config_string NAME_REGEX '.name_regex'
    set_config_string MAX_REPOS '.max_repos'
    set_config_string RATE_LIMIT_MODE '.rate_limit'
    set_config_string MAX_RETRIES '.max_retries'
    set_config_string RETRY_DELAY '.retry_delay'
    set_config_string LOG_FILE '.log_file'
    set_config_bool QUIET '.quiet'
    set_config_bool VERBOSE '.verbose'
    set_config_bool NO_COLOR '.no_color'
}

load_backup_config() {
    set_config_string MANIFEST '.manifest'
    set_config_string DEST_DIR '(.dest // .destination)'
    set_config_string BACKUP_MODE '.mode'
    set_config_string PROTOCOL '.protocol'
    set_config_string GITHUB_TOKEN '.token'
    set_config_bool RESUME '.resume'
    set_config_bool CHECKSUM '.checksum'
    set_config_bool VERIFY_AFTER_BACKUP '.verify_after_backup'
    set_config_string SLEEP_BETWEEN_REPOS '(.sleep // .sleep_between_repos)'
    set_config_string PARALLEL_JOBS '.parallel'
    set_config_bool NON_INTERACTIVE '.non_interactive'
    set_config_string LOG_FILE '.log_file'
    set_config_string LOCK_FILE '.lock_file'
    set_config_string STATE_FILE '.state_file'
    set_config_string RATE_LIMIT_MODE '.rate_limit'
    set_config_string MAX_RETRIES '.max_retries'
    set_config_string RETRY_DELAY '.retry_delay'
    set_config_string RETRY_BACKOFF '.retry_backoff'
    set_config_bool QUIET '.quiet'
    set_config_bool VERBOSE '.verbose'
    set_config_bool NO_COLOR '.no_color'
}

maybe_load_config() {
    local command="$1"
    shift

    CONFIG_FILE="$(config_arg_from_args "$@")"
    [[ -n "$CONFIG_FILE" ]] || return 0
    [[ -f "$CONFIG_FILE" ]] || die "Config file not found: $CONFIG_FILE"
    require_command jq

    case "$command" in
        discover) load_discover_config ;;
        backup) load_backup_config ;;
        *) ;;
    esac
}

trim_csv_cell() {
    local value="${1//$'\r'/}"
    value="${value#\"}"
    value="${value%\"}"
    printf '%s' "$value"
}

normalize_bool() {
    local value
    value="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
    case "$value" in
        true|yes|1) printf 'true' ;;
        false|no|0|"") printf 'false' ;;
        *) die "Invalid boolean value: $1" ;;
    esac
}

safe_repo_name() {
    printf '%s' "$1" | sed -E 's#[^A-Za-z0-9._-]+#__#g'
}

manifest_checksum() {
    sha256sum "$1" | awk '{print $1}'
}

countdown_sleep() {
    local seconds="$1"
    [[ "$seconds" =~ ^[0-9]+$ ]] || return 0
    (( seconds <= 0 )) && return 0
    info "Sleeping for ${seconds}s"
    sleep "$seconds"
}

header_value() {
    local headers_file="$1"
    local name="$2"
    awk -v wanted="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')" '
        BEGIN { FS=":" }
        {
            key=tolower($1)
            if (key == wanted) {
                value=$0
                sub(/^[^:]*:[[:space:]]*/, "", value)
                gsub(/\r/, "", value)
                print value
            }
        }
    ' "$headers_file" | tail -n 1
}

extract_next_link() {
    local headers_file="$1"
    awk 'tolower($0) ~ /^link:/ { print }' "$headers_file" \
        | sed -n 's/.*<\([^>]*\)>; rel="next".*/\1/p' \
        | tail -n 1
}

sleep_until_rate_limit_reset() {
    local headers_file="$1"
    local retry_after reset_epoch now wait_seconds

    retry_after="$(header_value "$headers_file" "retry-after")"
    if [[ -n "$retry_after" && "$retry_after" =~ ^[0-9]+$ ]]; then
        countdown_sleep "$retry_after"
        return 0
    fi

    reset_epoch="$(header_value "$headers_file" "x-ratelimit-reset")"
    if [[ -z "$reset_epoch" || ! "$reset_epoch" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    now="$(date +%s)"
    wait_seconds=$(( reset_epoch - now + 5 ))
    (( wait_seconds < 1 )) && wait_seconds=1

    if [[ "$RATE_LIMIT_MODE" == "wait" ]]; then
        warn "GitHub rate limit reached. Waiting ${wait_seconds}s for reset."
        countdown_sleep "$wait_seconds"
        return 0
    fi

    return 1
}

curl_headers() {
    local -n _headers_ref="$1"
    _headers_ref=(-H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28')
    if [[ -n "$GITHUB_TOKEN" ]]; then
        _headers_ref+=(-H "Authorization: Bearer $GITHUB_TOKEN")
    fi
}

###############################################################################
# GitHub API and download helpers
###############################################################################
github_api_page() {
    local url="$1"
    local attempt=1
    local delay="$RETRY_DELAY"
    local headers body status curl_rc remaining message
    local headers_arg=()

    curl_headers headers_arg
    GITHUB_NEXT_URL=""

    while true; do
        headers="$(mktemp)"
        body="$(mktemp)"
        debug "GitHub API GET $url"

        set +e
        status="$(curl -sS -L -w "%{http_code}" -D "$headers" -o "$body" "${headers_arg[@]}" "$url")"
        curl_rc=$?
        set -e

        if [[ $curl_rc -eq 0 && "$status" =~ ^2[0-9][0-9]$ ]]; then
            GITHUB_NEXT_URL="$(extract_next_link "$headers")"
            cat "$body"
            rm -f "$headers" "$body"
            return 0
        fi

        remaining="$(header_value "$headers" "x-ratelimit-remaining")"
        if [[ "$status" == "403" && "$remaining" == "0" ]]; then
            if sleep_until_rate_limit_reset "$headers"; then
                rm -f "$headers" "$body"
                continue
            fi
            rm -f "$headers" "$body"
            die "GitHub rate limit reached and --rate-limit is set to fail."
        fi

        message="$(jq -r '.message? // empty' "$body" 2>/dev/null || true)"
        if [[ -n "$message" && "$message" =~ [Rr]ate[[:space:]-]*limit|secondary[[:space:]-]*rate ]]; then
            warn "GitHub API reported rate limiting: $message"
            if [[ "$RATE_LIMIT_MODE" == "wait" && $attempt -le "$MAX_RETRIES" ]]; then
                rm -f "$headers" "$body"
                countdown_sleep "$delay"
                delay=$(( delay * RETRY_BACKOFF ))
                ((attempt++))
                continue
            fi
        fi

        if (( attempt > MAX_RETRIES )); then
            error "GitHub API request failed after $MAX_RETRIES retries: HTTP ${status:-unknown}"
            [[ -n "$message" ]] && error "GitHub message: $message"
            rm -f "$headers" "$body"
            return 1
        fi

        warn "GitHub API request failed with HTTP ${status:-unknown}. Retry ${attempt}/${MAX_RETRIES} in ${delay}s."
        rm -f "$headers" "$body"
        countdown_sleep "$delay"
        delay=$(( delay * RETRY_BACKOFF ))
        ((attempt++))
    done
}

github_api_paged() {
    local url="$1"
    local page

    while [[ -n "$url" ]]; do
        page="$(github_api_page "$url")" || return 1
        printf '%s\n' "$page"
        url="$GITHUB_NEXT_URL"
    done
}

download_with_retries() {
    local url="$1"
    local output="$2"
    local attempt=1
    local delay="$RETRY_DELAY"
    local headers status curl_rc remaining
    local headers_arg=()

    curl_headers headers_arg

    while true; do
        headers="$(mktemp)"
        debug "Downloading $url"

        set +e
        status="$(curl -sS -L -w "%{http_code}" -D "$headers" -o "$output" "${headers_arg[@]}" "$url")"
        curl_rc=$?
        set -e

        if [[ $curl_rc -eq 0 && "$status" =~ ^2[0-9][0-9]$ ]]; then
            rm -f "$headers"
            return 0
        fi

        remaining="$(header_value "$headers" "x-ratelimit-remaining")"
        if [[ "$status" == "403" && "$remaining" == "0" ]]; then
            if sleep_until_rate_limit_reset "$headers"; then
                rm -f "$headers"
                continue
            fi
            rm -f "$headers"
            return 1
        fi

        if (( attempt > MAX_RETRIES )); then
            rm -f "$headers"
            return 1
        fi

        warn "Download failed with HTTP ${status:-unknown}. Retry ${attempt}/${MAX_RETRIES} in ${delay}s."
        rm -f "$headers"
        countdown_sleep "$delay"
        delay=$(( delay * RETRY_BACKOFF ))
        ((attempt++))
    done
}

###############################################################################
# Manifest helpers
###############################################################################
write_json_manifest() {
    local repos_json_file="$1"
    local output="$2"
    local source_type="$3"
    local source_value="$4"
    local existing="${5:-}"
    local existing_arg

    existing_arg="$(mktemp)"
    if [[ -n "$existing" && -f "$existing" ]]; then
        manifest_to_json "$existing" > "$existing_arg"
    else
        printf '{"repositories":[]}\n' > "$existing_arg"
    fi

    jq -n \
        --arg created_at "$(now_utc_iso)" \
        --arg source_type "$source_type" \
        --arg source_value "$source_value" \
        --slurpfile repos "$repos_json_file" \
        --slurpfile old "$existing_arg" '
        ($old[0].repositories // [] | INDEX(.full_name)) as $existing |
        {
          version: 1,
          created_at: $created_at,
          source: {
            provider: "github",
            type: $source_type,
            value: $source_value
          },
          defaults: {
            enabled: true,
            mode: "mirror",
            protocol: "https",
            include_forks: true,
            include_archived: true,
            paths: [],
            exclude_paths: []
          },
          repositories: [
            $repos[0][]
            | . as $repo
            | ($existing[$repo.full_name] // {}) as $prev
            | $repo + {
                enabled: (if $prev | has("enabled") then $prev.enabled else true end),
                mode: ($prev.mode // "mirror"),
                paths: ($prev.paths // []),
                exclude_paths: ($prev.exclude_paths // [])
              }
          ]
        }
    ' > "$output"

    rm -f "$existing_arg"
}

json_manifest_to_csv() {
    local manifest="$1"
    local output="$2"

    {
        printf 'enabled,full_name,clone_url,ssh_url,html_url,default_branch,private,fork,archived,mode,paths,exclude_paths\n'
        jq -r '
            .repositories[]
            | [
                ((if has("enabled") then .enabled else true end) | tostring),
                (.full_name // ""),
                (.clone_url // ""),
                (.ssh_url // ""),
                (.html_url // ""),
                (.default_branch // ""),
                (.private // false | tostring),
                (.fork // false | tostring),
                (.archived // false | tostring),
                (.mode // "mirror"),
                ((.paths // []) | join(";")),
                ((.exclude_paths // []) | join(";"))
              ]
            | @tsv
        ' "$manifest" | while IFS=$'\t' read -r enabled full_name clone_url ssh_url html_url default_branch private fork archived mode paths exclude_paths; do
            printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
                "$enabled" "$full_name" "$clone_url" "$ssh_url" "$html_url" "$default_branch" \
                "$private" "$fork" "$archived" "$mode" "$paths" "$exclude_paths"
        done
    } > "$output"
}

csv_manifest_to_json() {
    local manifest="$1"
    local objects
    objects="$(mktemp)"

    tail -n +2 "$manifest" | while IFS=, read -r enabled full_name clone_url ssh_url html_url default_branch private fork archived mode paths exclude_paths _extra; do
        [[ -z "${full_name:-}" ]] && continue

        enabled="$(normalize_bool "$(trim_csv_cell "${enabled:-true}")")"
        private="$(normalize_bool "$(trim_csv_cell "${private:-false}")")"
        fork="$(normalize_bool "$(trim_csv_cell "${fork:-false}")")"
        archived="$(normalize_bool "$(trim_csv_cell "${archived:-false}")")"

        full_name="$(trim_csv_cell "${full_name:-}")"
        clone_url="$(trim_csv_cell "${clone_url:-}")"
        ssh_url="$(trim_csv_cell "${ssh_url:-}")"
        html_url="$(trim_csv_cell "${html_url:-}")"
        default_branch="$(trim_csv_cell "${default_branch:-}")"
        mode="$(trim_csv_cell "${mode:-mirror}")"
        paths="$(trim_csv_cell "${paths:-}")"
        exclude_paths="$(trim_csv_cell "${exclude_paths:-}")"

        jq -cn \
            --argjson enabled "$enabled" \
            --arg full_name "$full_name" \
            --arg clone_url "$clone_url" \
            --arg ssh_url "$ssh_url" \
            --arg html_url "$html_url" \
            --arg default_branch "$default_branch" \
            --argjson private "$private" \
            --argjson fork "$fork" \
            --argjson archived "$archived" \
            --arg mode "$mode" \
            --argjson paths "$(json_string_array_from_semicolon "$paths")" \
            --argjson exclude_paths "$(json_string_array_from_semicolon "$exclude_paths")" '
            {
              enabled: $enabled,
              full_name: $full_name,
              clone_url: $clone_url,
              ssh_url: $ssh_url,
              html_url: $html_url,
              default_branch: $default_branch,
              private: $private,
              fork: $fork,
              archived: $archived,
              mode: $mode,
              paths: $paths,
              exclude_paths: $exclude_paths
            }
        ' >> "$objects"
    done

    jq -s \
        --arg created_at "$(now_utc_iso)" '
        {
          version: 1,
          created_at: $created_at,
          source: {
            provider: "github",
            type: "csv",
            value: ""
          },
          defaults: {
            enabled: true,
            mode: "mirror",
            protocol: "https",
            include_forks: true,
            include_archived: true,
            paths: [],
            exclude_paths: []
          },
          repositories: .
        }
    ' "$objects"

    rm -f "$objects"
}

manifest_to_json() {
    local manifest="$1"

    [[ -f "$manifest" ]] || die "Manifest not found: $manifest"
    [[ -s "$manifest" ]] || die "Manifest is empty: $manifest"

    if jq -e 'type == "object" and has("repositories")' "$manifest" >/dev/null 2>&1; then
        jq '.' "$manifest"
    else
        csv_manifest_to_json "$manifest"
    fi
}

validate_manifest_file() {
    local manifest="$1"
    local tmp

    tmp="$(mktemp)"
    manifest_to_json "$manifest" > "$tmp"

    jq -e '
        type == "object"
        and (.repositories | type == "array")
        and all(.repositories[]; (.enabled | type == "boolean") and (.full_name | type == "string") and (.mode | type == "string"))
    ' "$tmp" >/dev/null || {
        rm -f "$tmp"
        die "Manifest validation failed: $manifest"
    }

    info "Manifest is valid: $manifest"
    info "Enabled repositories: $(jq '[.repositories[] | select(.enabled == true)] | length' "$tmp")"
    info "Total repositories: $(jq '.repositories | length' "$tmp")"
    rm -f "$tmp"
}

###############################################################################
# State helpers
###############################################################################
init_state_file() {
    local manifest_json="$1"
    local checksum="$2"

    if [[ "$RESUME" == true && -f "$STATE_FILE" ]]; then
        STATE_MANIFEST_CHECKSUM="$(jq -r '.manifest_checksum // empty' "$STATE_FILE")"
        if [[ -n "$STATE_MANIFEST_CHECKSUM" && "$STATE_MANIFEST_CHECKSUM" != "$checksum" ]]; then
            warn "State manifest checksum differs from current manifest. Completed entries may not match."
        fi
        RUN_DIR="$(jq -r '.run_dir // empty' "$STATE_FILE")"
        if [[ -z "$RUN_DIR" || ! -d "$RUN_DIR" ]]; then
            RUN_DIR="${DEST_DIR}/runs/$(now_utc_compact)"
        fi
        return 0
    fi

    RUN_DIR="${RUN_DIR:-${DEST_DIR}/runs/$(now_utc_compact)}"
    mkdir -p "$RUN_DIR"

    jq -n \
        --arg started_at "$(now_utc_iso)" \
        --arg manifest "$MANIFEST" \
        --arg manifest_checksum "$checksum" \
        --arg run_dir "$RUN_DIR" \
        --argjson repo_count "$(jq '.repositories | length' "$manifest_json")" '
        {
          version: 1,
          started_at: $started_at,
          updated_at: $started_at,
          manifest: $manifest,
          manifest_checksum: $manifest_checksum,
          run_dir: $run_dir,
          repo_count: $repo_count,
          repositories: {}
        }
    ' > "$STATE_FILE"
}

state_repo_status() {
    local key="$1"
    [[ -f "$STATE_FILE" ]] || {
        printf 'pending'
        return 0
    }
    jq -r --arg key "$key" '.repositories[$key].status // "pending"' "$STATE_FILE"
}

update_state_repo() {
    local key="$1"
    local status="$2"
    local full_name="$3"
    local mode="$4"
    local output_path="$5"
    local error_message="${6:-}"
    local tmp

    tmp="$(mktemp)"
    jq \
        --arg updated_at "$(now_utc_iso)" \
        --arg key "$key" \
        --arg status "$status" \
        --arg full_name "$full_name" \
        --arg mode "$mode" \
        --arg output_path "$output_path" \
        --arg error_message "$error_message" '
        .updated_at = $updated_at
        | .repositories[$key] = {
            status: $status,
            full_name: $full_name,
            mode: $mode,
            output_path: $output_path,
            error: $error_message,
            updated_at: $updated_at
          }
    ' "$STATE_FILE" > "$tmp"
    mv "$tmp" "$STATE_FILE"
}

write_summary() {
    local summary_file="$RUN_DIR/summary.json"
    jq '
        . as $state
        | {
            started_at: $state.started_at,
            updated_at: $state.updated_at,
            manifest: $state.manifest,
            run_dir: $state.run_dir,
            repo_count: $state.repo_count,
            done: ([.repositories[] | select(.status == "done")] | length),
            failed: ([.repositories[] | select(.status == "failed")] | length),
            skipped: ([.repositories[] | select(.status == "skipped")] | length),
            repositories: $state.repositories
          }
    ' "$STATE_FILE" > "$summary_file"
    info "Summary written to $summary_file"
}

###############################################################################
# Discovery
###############################################################################
parse_discover_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --user) GITHUB_USER="${2:-}"; shift 2 ;;
            --org) GITHUB_ORG="${2:-}"; shift 2 ;;
            --authenticated-user) AUTHENTICATED_USER=true; shift ;;
            --token) GITHUB_TOKEN="${2:-}"; shift 2 ;;
            --output) OUTPUT_FILE="${2:-}"; shift 2 ;;
            --format) OUTPUT_FORMAT="${2:-}"; shift 2 ;;
            --input) INPUT_MANIFEST="${2:-}"; shift 2 ;;
            --config) CONFIG_FILE="${2:-}"; shift 2 ;;
            --include-forks) DISCOVER_INCLUDE_FORKS=true; shift ;;
            --exclude-forks) DISCOVER_INCLUDE_FORKS=false; shift ;;
            --include-archived) DISCOVER_INCLUDE_ARCHIVED=true; shift ;;
            --exclude-archived) DISCOVER_INCLUDE_ARCHIVED=false; shift ;;
            --visibility) VISIBILITY="${2:-}"; shift 2 ;;
            --name-regex) NAME_REGEX="${2:-}"; shift 2 ;;
            --max-repos) MAX_REPOS="${2:-}"; shift 2 ;;
            --rate-limit) RATE_LIMIT_MODE="${2:-}"; shift 2 ;;
            --max-retries) MAX_RETRIES="${2:-}"; shift 2 ;;
            --retry-delay) RETRY_DELAY="${2:-}"; shift 2 ;;
            --log-file) LOG_FILE="${2:-}"; shift 2 ;;
            --quiet) QUIET=true; shift ;;
            --verbose) VERBOSE=true; shift ;;
            --no-color) NO_COLOR=true; shift ;;
            -h|--help) print_discover_usage; exit 0 ;;
            *) die "Unknown discover argument: $1" ;;
        esac
    done

    [[ -n "$OUTPUT_FILE" ]] || die "discover requires --output FILE."
    case "$OUTPUT_FORMAT" in json|csv) ;; *) die "--format must be json or csv." ;; esac
    case "$VISIBILITY" in all|public|private) ;; *) die "--visibility must be all, public, or private." ;; esac
    case "$RATE_LIMIT_MODE" in wait|fail) ;; *) die "--rate-limit must be wait or fail." ;; esac
    is_positive_integer "$MAX_RETRIES" || die "--max-retries expects a positive integer."
    is_non_negative_integer "$RETRY_DELAY" || die "--retry-delay expects a non-negative integer."
    [[ -z "$MAX_REPOS" ]] || is_positive_integer "$MAX_REPOS" || die "--max-repos expects a positive integer."

    local sources=0
    [[ -n "$GITHUB_USER" ]] && ((sources += 1))
    [[ -n "$GITHUB_ORG" ]] && ((sources += 1))
    [[ "$AUTHENTICATED_USER" == true ]] && ((sources += 1))
    (( sources == 1 )) || die "Specify exactly one of --user, --org, or --authenticated-user."

    if [[ "$AUTHENTICATED_USER" == true && -z "$GITHUB_TOKEN" ]]; then
        die "--authenticated-user requires --token or GITHUB_TOKEN."
    fi
}

set_discover_endpoint_and_source() {
    if [[ "$AUTHENTICATED_USER" == true ]]; then
        DISCOVER_ENDPOINT="https://api.github.com/user/repos?per_page=100&visibility=${VISIBILITY}"
        DISCOVER_SOURCE_TYPE="authenticated-user"
        DISCOVER_SOURCE_VALUE="token-owner"
    elif [[ -n "$GITHUB_USER" ]]; then
        DISCOVER_ENDPOINT="https://api.github.com/users/${GITHUB_USER}/repos?per_page=100&type=all"
        DISCOVER_SOURCE_TYPE="user"
        DISCOVER_SOURCE_VALUE="$GITHUB_USER"
    else
        DISCOVER_ENDPOINT="https://api.github.com/orgs/${GITHUB_ORG}/repos?per_page=100&type=all"
        DISCOVER_SOURCE_TYPE="org"
        DISCOVER_SOURCE_VALUE="$GITHUB_ORG"
    fi
}

discover_repositories() {
    local pages_file filtered_file json_output

    set_discover_endpoint_and_source
    pages_file="$(mktemp)"
    filtered_file="$(mktemp)"
    json_output="$(mktemp)"

    info "Discovering repositories from GitHub source: ${DISCOVER_SOURCE_TYPE}=${DISCOVER_SOURCE_VALUE}"
    github_api_paged "$DISCOVER_ENDPOINT" > "$pages_file"

    jq -s \
        --argjson include_forks "$DISCOVER_INCLUDE_FORKS" \
        --argjson include_archived "$DISCOVER_INCLUDE_ARCHIVED" \
        --arg visibility "$VISIBILITY" \
        --arg name_regex "$NAME_REGEX" \
        --arg max_repos "${MAX_REPOS:-0}" '
        add
        | map(select($include_forks or (.fork | not)))
        | map(select($include_archived or (.archived | not)))
        | map(select(
            $visibility == "all"
            or ($visibility == "private" and (.private == true))
            or ($visibility == "public" and (.private == false))
          ))
        | map(select($name_regex == "" or (.full_name | test($name_regex))))
        | if ($max_repos | tonumber) > 0 then .[:($max_repos | tonumber)] else . end
        | map({
            full_name,
            name,
            owner: .owner.login,
            clone_url,
            ssh_url,
            html_url,
            default_branch,
            private,
            fork,
            archived,
            disabled,
            size,
            pushed_at,
            updated_at,
            language,
            topics: (.topics // [])
          })
    ' "$pages_file" > "$filtered_file"

    write_json_manifest "$filtered_file" "$json_output" "$DISCOVER_SOURCE_TYPE" "$DISCOVER_SOURCE_VALUE" "$INPUT_MANIFEST"

    mkdir -p "$(dirname "$OUTPUT_FILE")"
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        mv "$json_output" "$OUTPUT_FILE"
    else
        json_manifest_to_csv "$json_output" "$OUTPUT_FILE"
        rm -f "$json_output"
    fi

    info "Manifest written to $OUTPUT_FILE"
    info "Repositories in manifest: $(jq '. | length' "$filtered_file")"

    rm -f "$pages_file" "$filtered_file"
}

###############################################################################
# Backup
###############################################################################
parse_backup_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --manifest) MANIFEST="${2:-}"; shift 2 ;;
            --dest) DEST_DIR="${2:-}"; shift 2 ;;
            --config) CONFIG_FILE="${2:-}"; shift 2 ;;
            --mode) BACKUP_MODE="${2:-}"; shift 2 ;;
            --protocol) PROTOCOL="${2:-}"; shift 2 ;;
            --token) GITHUB_TOKEN="${2:-}"; shift 2 ;;
            --resume) RESUME=true; shift ;;
            --checksum) CHECKSUM=true; shift ;;
            --no-checksum) CHECKSUM=false; shift ;;
            --verify-after-backup) VERIFY_AFTER_BACKUP=true; shift ;;
            --sleep) SLEEP_BETWEEN_REPOS="${2:-}"; shift 2 ;;
            --parallel) PARALLEL_JOBS="${2:-}"; shift 2 ;;
            --non-interactive) NON_INTERACTIVE=true; shift ;;
            --log-file) LOG_FILE="${2:-}"; shift 2 ;;
            --lock-file) LOCK_FILE="${2:-}"; shift 2 ;;
            --state-file) STATE_FILE="${2:-}"; shift 2 ;;
            --rate-limit) RATE_LIMIT_MODE="${2:-}"; shift 2 ;;
            --max-retries) MAX_RETRIES="${2:-}"; shift 2 ;;
            --retry-delay) RETRY_DELAY="${2:-}"; shift 2 ;;
            --retry-backoff) RETRY_BACKOFF="${2:-}"; shift 2 ;;
            --quiet) QUIET=true; shift ;;
            --verbose) VERBOSE=true; shift ;;
            --no-color) NO_COLOR=true; shift ;;
            -h|--help) print_backup_usage; exit 0 ;;
            *) die "Unknown backup argument: $1" ;;
        esac
    done

    [[ -n "$MANIFEST" ]] || die "backup requires --manifest FILE."
    [[ -n "$DEST_DIR" ]] || die "backup requires --dest DIR."
    [[ -z "$BACKUP_MODE" || "$BACKUP_MODE" =~ ^(mirror|clone|archive|sparse)$ ]] || die "--mode must be mirror, clone, archive, or sparse."
    [[ "$PROTOCOL" =~ ^(https|ssh)$ ]] || die "--protocol must be https or ssh."
    case "$RATE_LIMIT_MODE" in wait|fail) ;; *) die "--rate-limit must be wait or fail." ;; esac
    is_positive_integer "$MAX_RETRIES" || die "--max-retries expects a positive integer."
    is_non_negative_integer "$RETRY_DELAY" || die "--retry-delay expects a non-negative integer."
    is_positive_integer "$RETRY_BACKOFF" || die "--retry-backoff expects a positive integer."
    is_non_negative_integer "$SLEEP_BETWEEN_REPOS" || die "--sleep expects a non-negative integer."
    is_positive_integer "$PARALLEL_JOBS" || die "--parallel expects a positive integer."

    if (( PARALLEL_JOBS > 1 )); then
        warn "--parallel is accepted for compatibility, but resumable stateful backup currently runs serially."
    fi
    if [[ "$NON_INTERACTIVE" == true ]]; then
        debug "Running in non-interactive mode."
    fi

    mkdir -p "$DEST_DIR"
    STATE_FILE="${STATE_FILE:-${DEST_DIR}/.github-backup-state.json}"
    LOCK_FILE="${LOCK_FILE:-${DEST_DIR}/.github-backup.lock}"
}

acquire_lock() {
    [[ -n "$LOCK_FILE" ]] || return 0
    mkdir -p "$(dirname "$LOCK_FILE")"
    exec 9>"$LOCK_FILE"
    flock -n 9 || die "Another backup appears to be running. Lock file: $LOCK_FILE"
}

repo_clone_url() {
    local repo_json="$1"
    local clone_url ssh_url full_name

    clone_url="$(jq -r '.clone_url // empty' <<< "$repo_json")"
    ssh_url="$(jq -r '.ssh_url // empty' <<< "$repo_json")"
    full_name="$(jq -r '.full_name' <<< "$repo_json")"

    if [[ "$PROTOCOL" == "ssh" ]]; then
        if [[ -n "$ssh_url" ]]; then
            printf '%s' "$ssh_url"
        else
            printf 'git@github.com:%s.git' "$full_name"
        fi
    else
        if [[ -n "$clone_url" ]]; then
            printf '%s' "$clone_url"
        else
            printf 'https://github.com/%s.git' "$full_name"
        fi
    fi
}

git_with_optional_auth() {
    if [[ -n "$GITHUB_TOKEN" && "$PROTOCOL" == "https" ]]; then
        GIT_TERMINAL_PROMPT=0 \
        GIT_CONFIG_COUNT=1 \
        GIT_CONFIG_KEY_0='http.https://github.com/.extraheader' \
        GIT_CONFIG_VALUE_0="AUTHORIZATION: bearer $GITHUB_TOKEN" \
            git "$@"
    else
        GIT_TERMINAL_PROMPT=0 git "$@"
    fi
}

archive_url_for_repo() {
    local full_name="$1"
    local ref="$2"
    printf 'https://api.github.com/repos/%s/tarball/%s' "$full_name" "$ref"
}

read_json_array_into() {
    local repo_json="$1"
    local field="$2"
    local -n array_ref="$3"
    # shellcheck disable=SC2034 # array_ref is a nameref output parameter.
    mapfile -t array_ref < <(jq -r --arg field "$field" '.[$field][]? // empty' <<< "$repo_json")
}

backup_mirror_repo() {
    local repo_json="$1"
    local full_name="$2"
    local output_path="$3"
    local url

    url="$(repo_clone_url "$repo_json")"
    if [[ -d "$output_path" ]]; then
        info "Updating mirror: $full_name"
        git_with_optional_auth -C "$output_path" remote update --prune || return 1
    else
        info "Creating mirror: $full_name"
        git_with_optional_auth clone --mirror "$url" "$output_path" || return 1
    fi
}

backup_clone_repo() {
    local repo_json="$1"
    local full_name="$2"
    local output_path="$3"
    local url

    url="$(repo_clone_url "$repo_json")"
    if [[ -d "$output_path/.git" ]]; then
        info "Updating clone: $full_name"
        git_with_optional_auth -C "$output_path" fetch --all --prune --tags || return 1
        git_with_optional_auth -C "$output_path" pull --ff-only || warn "Pull failed for $full_name after fetch. Working tree may have local changes."
    else
        info "Creating clone: $full_name"
        git_with_optional_auth clone "$url" "$output_path" || return 1
    fi
}

backup_sparse_repo() {
    local repo_json="$1"
    local full_name="$2"
    local output_path="$3"
    local url default_branch
    local paths=()

    read_json_array_into "$repo_json" "paths" paths
    if (( ${#paths[@]} == 0 )); then
        warn "Sparse mode requested for $full_name without paths. Falling back to clone mode."
        backup_clone_repo "$repo_json" "$full_name" "$output_path"
        return
    fi

    url="$(repo_clone_url "$repo_json")"
    default_branch="$(jq -r '.default_branch // "main"' <<< "$repo_json")"

    if [[ -d "$output_path/.git" ]]; then
        info "Updating sparse clone: $full_name"
        git_with_optional_auth -C "$output_path" sparse-checkout set "${paths[@]}" || return 1
        git_with_optional_auth -C "$output_path" fetch --all --prune --tags || return 1
        git_with_optional_auth -C "$output_path" checkout "$default_branch" || true
        git_with_optional_auth -C "$output_path" pull --ff-only || warn "Pull failed for sparse clone $full_name."
    else
        info "Creating sparse clone: $full_name"
        git_with_optional_auth clone --filter=blob:none --sparse "$url" "$output_path" || return 1
        git_with_optional_auth -C "$output_path" sparse-checkout set "${paths[@]}" || return 1
    fi
}

backup_archive_repo() {
    local repo_json="$1"
    local full_name="$2"
    local output_path="$3"
    local default_branch url tmp_archive tmp_dir extract_dir root_dir
    local paths=()
    local exclude_paths=()
    local tar_excludes=()

    default_branch="$(jq -r '.default_branch // "main"' <<< "$repo_json")"
    url="$(archive_url_for_repo "$full_name" "$default_branch")"
    tmp_archive="$(mktemp)"

    info "Downloading archive: $full_name@$default_branch"
    download_with_retries "$url" "$tmp_archive" || {
        rm -f "$tmp_archive"
        return 1
    }

    read_json_array_into "$repo_json" "paths" paths
    read_json_array_into "$repo_json" "exclude_paths" exclude_paths

    mkdir -p "$(dirname "$output_path")"
    if (( ${#paths[@]} == 0 && ${#exclude_paths[@]} == 0 )); then
        mv "$tmp_archive" "$output_path" || return 1
        return 0
    fi

    tmp_dir="$(mktemp -d)"
    extract_dir="$tmp_dir/extract"
    mkdir -p "$extract_dir"
    tar -xzf "$tmp_archive" -C "$extract_dir" || {
        rm -rf "$tmp_dir" "$tmp_archive"
        return 1
    }
    root_dir="$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    [[ -n "$root_dir" ]] || {
        rm -rf "$tmp_dir" "$tmp_archive"
        return 1
    }

    for excluded in "${exclude_paths[@]}"; do
        tar_excludes+=(--exclude="$excluded")
    done

    if (( ${#paths[@]} == 0 )); then
        paths=(".")
    fi

    info "Creating filtered archive for $full_name"
    tar -czf "${output_path}.tmp" -C "$root_dir" "${tar_excludes[@]}" "${paths[@]}" || {
        rm -rf "$tmp_dir" "$tmp_archive"
        return 1
    }
    mv "${output_path}.tmp" "$output_path" || {
        rm -rf "$tmp_dir" "$tmp_archive"
        return 1
    }
    rm -rf "$tmp_dir" "$tmp_archive"
}

verify_backup_output() {
    local mode="$1"
    local output_path="$2"

    [[ "$VERIFY_AFTER_BACKUP" == true ]] || return 0

    case "$mode" in
        mirror)
            git -C "$output_path" rev-parse --is-bare-repository >/dev/null
            ;;
        clone|sparse)
            git -C "$output_path" rev-parse --is-inside-work-tree >/dev/null
            ;;
        archive)
            tar -tzf "$output_path" >/dev/null
            ;;
    esac
}

write_archive_checksum() {
    local output_path="$1"
    local checksum_file="$RUN_DIR/checksums.sha256"

    [[ "$CHECKSUM" == true ]] || return 0
    sha256sum "$output_path" >> "$checksum_file"
}

backup_repo_once() {
    local repo_json="$1"
    local full_name mode safe output_path

    full_name="$(jq -r '.full_name' <<< "$repo_json")"
    safe="$(safe_repo_name "$full_name")"
    mode="${BACKUP_MODE:-$(jq -r '.mode // "mirror"' <<< "$repo_json")}"

    case "$mode" in
        mirror) output_path="$RUN_DIR/repos/${safe}.git" ;;
        clone|sparse) output_path="$RUN_DIR/repos/${safe}" ;;
        archive) output_path="$RUN_DIR/archives/${safe}.tar.gz" ;;
        *) die "Invalid backup mode for $full_name: $mode" ;;
    esac

    mkdir -p "$RUN_DIR/repos" "$RUN_DIR/archives"

    case "$mode" in
        mirror) backup_mirror_repo "$repo_json" "$full_name" "$output_path" ;;
        clone) backup_clone_repo "$repo_json" "$full_name" "$output_path" ;;
        sparse) backup_sparse_repo "$repo_json" "$full_name" "$output_path" ;;
        archive) backup_archive_repo "$repo_json" "$full_name" "$output_path" ;;
    esac

    verify_backup_output "$mode" "$output_path" || return 1
    if [[ "$mode" == "archive" ]]; then
        write_archive_checksum "$output_path" || return 1
    fi

    printf '%s' "$output_path"
}

backup_repo_with_retries() {
    local repo_json="$1"
    local full_name mode key status output_path
    local attempt=1
    local delay="$RETRY_DELAY"

    full_name="$(jq -r '.full_name' <<< "$repo_json")"
    mode="${BACKUP_MODE:-$(jq -r '.mode // "mirror"' <<< "$repo_json")}"
    key="$(safe_repo_name "$full_name")"
    status="$(state_repo_status "$key")"

    if [[ "$RESUME" == true && "$status" == "done" ]]; then
        info "Skipping completed repository from state: $full_name"
        return 0
    fi

    while true; do
        update_state_repo "$key" "running" "$full_name" "$mode" "" ""
        if output_path="$(backup_repo_once "$repo_json")"; then
            update_state_repo "$key" "done" "$full_name" "$mode" "$output_path" ""
            info "Completed $full_name -> $output_path"
            return 0
        fi

        if (( attempt > MAX_RETRIES )); then
            update_state_repo "$key" "failed" "$full_name" "$mode" "" "backup failed after retries"
            error "Backup failed for $full_name after $MAX_RETRIES retries."
            return 1
        fi

        warn "Backup failed for $full_name. Retry ${attempt}/${MAX_RETRIES} in ${delay}s."
        update_state_repo "$key" "failed" "$full_name" "$mode" "" "retry pending"
        countdown_sleep "$delay"
        delay=$(( delay * RETRY_BACKOFF ))
        ((attempt++))
    done
}

run_backup() {
    local manifest_json checksum repo_count enabled_count failures=0
    local repos_file repo_json

    manifest_json="$(mktemp)"
    manifest_to_json "$MANIFEST" > "$manifest_json"
    validate_manifest_file "$manifest_json"

    checksum="$(manifest_checksum "$manifest_json")"
    mkdir -p "$DEST_DIR"
    init_state_file "$manifest_json" "$checksum"
    mkdir -p "$RUN_DIR/repos" "$RUN_DIR/archives"

    info "Backup run directory: $RUN_DIR"
    info "State file: $STATE_FILE"

    repos_file="$(mktemp)"
    jq -c '.repositories[] | select(.enabled == true)' "$manifest_json" > "$repos_file"
    repo_count="$(jq '.repositories | length' "$manifest_json")"
    enabled_count="$(wc -l < "$repos_file" | tr -d ' ')"
    info "Manifest repositories: $repo_count total, $enabled_count enabled."

    while IFS= read -r repo_json; do
        [[ -z "$repo_json" ]] && continue
        if ! backup_repo_with_retries "$repo_json"; then
            failures=$((failures + 1))
        fi
        countdown_sleep "$SLEEP_BETWEEN_REPOS"
    done < "$repos_file"

    write_summary
    rm -f "$manifest_json" "$repos_file"

    if (( failures > 0 )); then
        die "$failures repository backup(s) failed. Re-run with --resume after fixing the issue."
    fi

    info "Backup completed successfully."
}

###############################################################################
# Convert and validate commands
###############################################################################
parse_validate_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --manifest) MANIFEST="${2:-}"; shift 2 ;;
            --log-file) LOG_FILE="${2:-}"; shift 2 ;;
            --quiet) QUIET=true; shift ;;
            --verbose) VERBOSE=true; shift ;;
            --no-color) NO_COLOR=true; shift ;;
            -h|--help)
                printf 'Usage: %s validate-manifest --manifest FILE\n' "$SCRIPT_NAME"
                exit 0
                ;;
            *) die "Unknown validate-manifest argument: $1" ;;
        esac
    done
    [[ -n "$MANIFEST" ]] || die "validate-manifest requires --manifest FILE."
}

parse_convert_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --manifest) MANIFEST="${2:-}"; shift 2 ;;
            --output) OUTPUT_FILE="${2:-}"; shift 2 ;;
            --format) OUTPUT_FORMAT="${2:-}"; shift 2 ;;
            --log-file) LOG_FILE="${2:-}"; shift 2 ;;
            --quiet) QUIET=true; shift ;;
            --verbose) VERBOSE=true; shift ;;
            --no-color) NO_COLOR=true; shift ;;
            -h|--help)
                printf 'Usage: %s convert-manifest --manifest FILE --output FILE --format json|csv\n' "$SCRIPT_NAME"
                exit 0
                ;;
            *) die "Unknown convert-manifest argument: $1" ;;
        esac
    done
    [[ -n "$MANIFEST" ]] || die "convert-manifest requires --manifest FILE."
    [[ -n "$OUTPUT_FILE" ]] || die "convert-manifest requires --output FILE."
    case "$OUTPUT_FORMAT" in json|csv) ;; *) die "--format must be json or csv." ;; esac
}

run_convert_manifest() {
    local tmp
    tmp="$(mktemp)"
    manifest_to_json "$MANIFEST" > "$tmp"
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        jq '.' "$tmp" > "$OUTPUT_FILE"
    else
        json_manifest_to_csv "$tmp" "$OUTPUT_FILE"
    fi
    rm -f "$tmp"
    info "Converted manifest written to $OUTPUT_FILE"
}

###############################################################################
# Main
###############################################################################
main() {
    COMMAND="${1:-}"
    [[ -n "$COMMAND" ]] || {
        print_usage
        exit 1
    }
    shift || true

    case "$COMMAND" in
        discover)
            maybe_load_config "$COMMAND" "$@"
            parse_discover_args "$@"
            check_common_dependencies
            discover_repositories
            ;;
        backup)
            maybe_load_config "$COMMAND" "$@"
            parse_backup_args "$@"
            check_backup_dependencies
            acquire_lock
            run_backup
            ;;
        validate-manifest)
            parse_validate_args "$@"
            require_command jq
            validate_manifest_file "$MANIFEST"
            ;;
        convert-manifest)
            parse_convert_args "$@"
            require_command jq
            run_convert_manifest
            ;;
        -h|--help|help)
            print_usage
            ;;
        *)
            die "Unknown command: $COMMAND"
            ;;
    esac
}

main "$@"
