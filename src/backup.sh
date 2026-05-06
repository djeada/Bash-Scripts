#!/usr/bin/env bash

# Script Name: backup.sh
# Description: Creates reliable filesystem backups with optional compression,
#              symmetric GPG encryption, retention cleanup, and an interactive
#              menu for ad-hoc or cron-friendly usage.
# Usage:
#   ./backup.sh
#   ./backup.sh --auto --source "$HOME/Documents" --dest /mnt/backups --compress
#   ./backup.sh --auto --dest /mnt/backups --exclude '*.cache' --retention-daily 14

set -euo pipefail
IFS=$'\n\t'

###############################################################################
# Globals
###############################################################################
SCRIPT_NAME="$(basename "$0")"
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
HOST_TAG="$(hostname -s 2>/dev/null || hostname 2>/dev/null || printf 'host')"
HOST_TAG="${HOST_TAG//[^[:alnum:]._-]/-}"

DEFAULT_SOURCE_DIRS=(
    "$HOME/Documents"
    "$HOME/Downloads"
    "$HOME/Desktop"
)

SOURCE_DIRS=()
EXCLUDE_PATTERNS=()
TARGET_DIR=""

COMPRESS=false
ENCRYPT=false
GPG_PASSPHRASE=""
GPG_PASSPHRASE_FILE=""

RETENTION_DAILY=7
RETENTION_WEEKLY=4
RETENTION_MONTHLY=3

AUTO_MODE=false
BACKUP_REQUESTED=false
QUIET=false
VERBOSE=false
NO_COLOR=false

CURRENT_ARTIFACT=""
LOCK_DIR=""
BACKUP_SUCCEEDED=false

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
    local timestamp plain rendered label

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
}

die() {
    log_msg ERROR "$*"
    exit 1
}

###############################################################################
# Cleanup
###############################################################################
cleanup() {
    local exit_code=$?

    trap - EXIT INT TERM

    if [[ $exit_code -ne 0 && "$BACKUP_SUCCEEDED" != true && -n "$CURRENT_ARTIFACT" && -e "$CURRENT_ARTIFACT" ]]; then
        log_msg WARN "Removing incomplete backup artifact: $CURRENT_ARTIFACT"
        rm -rf -- "$CURRENT_ARTIFACT"
    fi

    if [[ -n "$LOCK_DIR" && -d "$LOCK_DIR" ]]; then
        rmdir -- "$LOCK_DIR" 2>/dev/null || true
    fi

    exit "$exit_code"
}

trap cleanup EXIT INT TERM

###############################################################################
# Usage
###############################################################################
print_usage() {
    cat <<EOF
Usage:
  $SCRIPT_NAME
  $SCRIPT_NAME --auto [options]

Options:
  --source PATH                 Add a source file or directory to the backup.
                                Can be used multiple times. Defaults to:
                                ${DEFAULT_SOURCE_DIRS[*]}
  --dest DIR                    Backup destination root directory.
  --exclude PATTERN             rsync exclude pattern. Can be used multiple times.
  --compress                    Package the backup as .tar.gz.
  --encrypt                     Encrypt the final artifact with symmetric GPG.
  --gpg-passphrase VALUE        Passphrase for --encrypt.
  --gpg-passphrase-file FILE    Read GPG passphrase from FILE.
  --retention-daily N           Keep all backups from the last N days. Default: $RETENTION_DAILY
  --retention-weekly N          Then keep one backup per week for N weeks. Default: $RETENTION_WEEKLY
  --retention-monthly N         Then keep one backup per month for N months. Default: $RETENTION_MONTHLY
  --auto                        Run non-interactively.
  -q, --quiet                   Hide informational logs.
  -v, --verbose                 Print debug logs.
      --no-color                Disable colored log labels.
  -h, --help                    Show this help message.

Examples:
  $SCRIPT_NAME --auto --dest /mnt/backups
  $SCRIPT_NAME --auto --source "\$HOME/Documents" --source "\$HOME/Pictures" --dest /mnt/backups --compress
  $SCRIPT_NAME --auto --dest /mnt/backups --compress --encrypt --gpg-passphrase-file ~/.config/backup.pass
EOF
}

press_enter_to_continue() {
    echo
    read -r -p "Press [Enter] to continue..."
}

prompt_yes_no() {
    local prompt="$1"
    local default_answer="${2:-y}"
    local answer=""

    while true; do
        read -r -p "$prompt" answer
        answer="${answer:-$default_answer}"
        case "$answer" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

###############################################################################
# Validation helpers
###############################################################################
require_command() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
}

canonical_path() {
    local path="$1"

    if [[ -d "$path" ]]; then
        (
            cd "$path" >/dev/null 2>&1 &&
                pwd -P
        )
        return
    fi

    if [[ -e "$path" ]]; then
        (
            cd "$(dirname "$path")" >/dev/null 2>&1 &&
                printf '%s/%s\n' "$(pwd -P)" "$(basename "$path")"
        )
        return
    fi

    if [[ -d "$(dirname "$path")" ]]; then
        (
            cd "$(dirname "$path")" >/dev/null 2>&1 &&
                printf '%s/%s\n' "$(pwd -P)" "$(basename "$path")"
        )
        return
    fi

    printf '%s\n' "$path"
}

is_non_negative_integer() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

validate_retention_value() {
    local label="$1"
    local value="$2"

    is_non_negative_integer "$value" || die "$label must be a non-negative integer."
}

validate_backup_target() {
    local target_canon source source_canon

    target_canon="$(canonical_path "$TARGET_DIR")"
    for source in "${SOURCE_DIRS[@]}"; do
        [[ -d "$source" ]] || continue
        source_canon="$(canonical_path "$source")"
        case "$target_canon/" in
            "$source_canon/"*)
                die "Backup destination must not be inside source directory: $source"
                ;;
        esac
    done
}

validate_configuration() {
    local source valid_sources=0

    require_command rsync
    require_command tar
    require_command date
    require_command find
    require_command hostname
    require_command mktemp

    [[ -n "$TARGET_DIR" ]] || die "Backup destination is required."
    mkdir -p -- "$TARGET_DIR"

    validate_retention_value "Daily retention" "$RETENTION_DAILY"
    validate_retention_value "Weekly retention" "$RETENTION_WEEKLY"
    validate_retention_value "Monthly retention" "$RETENTION_MONTHLY"

    if [[ ${#SOURCE_DIRS[@]} -eq 0 ]]; then
        die "At least one source file or directory is required."
    fi

    for source in "${SOURCE_DIRS[@]}"; do
        if [[ -e "$source" ]]; then
            valid_sources=$((valid_sources + 1))
        else
            log_msg WARN "Source does not exist and will be skipped: $source"
        fi
    done

    [[ $valid_sources -gt 0 ]] || die "None of the configured sources exist."

    if [[ "$ENCRYPT" == true ]]; then
        require_command gpg

        if [[ -n "$GPG_PASSPHRASE" && -n "$GPG_PASSPHRASE_FILE" ]]; then
            die "Use either --gpg-passphrase or --gpg-passphrase-file, not both."
        fi

        if [[ -n "$GPG_PASSPHRASE_FILE" ]]; then
            [[ -f "$GPG_PASSPHRASE_FILE" ]] || die "GPG passphrase file not found: $GPG_PASSPHRASE_FILE"
        elif [[ -z "$GPG_PASSPHRASE" ]]; then
            die "Encryption requires --gpg-passphrase or --gpg-passphrase-file."
        fi
    fi

    validate_backup_target
}

###############################################################################
# Interactive selection
###############################################################################
load_default_sources() {
    local dir

    SOURCE_DIRS=()
    for dir in "${DEFAULT_SOURCE_DIRS[@]}"; do
        [[ -e "$dir" ]] || continue
        SOURCE_DIRS+=("$dir")
    done
}

read_paths_into_array() {
    local -n target_ref="$1"
    local prompt="$2"
    local value=""

    while true; do
        read -r -p "$prompt" value
        [[ -z "$value" ]] && break
        target_ref+=("$value")
    done
}

select_source_directories() {
    local choice=""
    local extras=()

    load_default_sources

    echo
    echo "Default backup sources:"
    if [[ ${#SOURCE_DIRS[@]} -eq 0 ]]; then
        echo " - No default directories currently exist on this machine."
    else
        printf ' - %s\n' "${SOURCE_DIRS[@]}"
    fi

    echo
    echo "K) Keep current defaults"
    echo "A) Add more paths"
    echo "C) Choose custom paths only"
    read -r -p "Choose [K/A/C]: " choice

    case "$choice" in
        [Aa]*)
            echo "Enter one path per line. Submit an empty line when done."
            read_paths_into_array extras "Additional source path: "
            SOURCE_DIRS+=("${extras[@]}")
            ;;
        [Cc]*)
            SOURCE_DIRS=()
            echo "Enter one path per line. Submit an empty line when done."
            read_paths_into_array SOURCE_DIRS "Source path: "
            ;;
        *)
            ;;
    esac
}

detect_usb_drives() {
    command -v lsblk >/dev/null 2>&1 || return 0
    lsblk -nr -o RM,MOUNTPOINT | awk '$1=="1" && $2!="" {print $2}'
}

select_target_directory() {
    local choice="" custom_path="" usb_choice=""
    local usb_drives=()

    while true; do
        echo
        echo "Select backup destination:"
        echo "1) Enter a custom path"
        echo "2) Choose from detected USB drives"
        echo "3) Cancel"
        read -r -p "Enter your choice [1-3]: " choice

        case "$choice" in
            1)
                read -r -p "Enter destination directory: " custom_path
                [[ -n "$custom_path" ]] || {
                    echo "Destination cannot be empty."
                    continue
                }
                TARGET_DIR="$custom_path"
                return 0
                ;;
            2)
                mapfile -t usb_drives < <(detect_usb_drives)
                if [[ ${#usb_drives[@]} -eq 0 ]]; then
                    echo "No mounted removable drives detected."
                    continue
                fi

                printf '%s\n' "${usb_drives[@]}" | nl -w1 -s') '
                read -r -p "Select a drive by number: " usb_choice
                if [[ "$usb_choice" =~ ^[0-9]+$ ]] && (( usb_choice >= 1 && usb_choice <= ${#usb_drives[@]} )); then
                    TARGET_DIR="${usb_drives[$((usb_choice - 1))]}"
                    return 0
                fi
                echo "Invalid drive selection."
                ;;
            3)
                return 1
                ;;
            *)
                echo "Invalid choice."
                ;;
        esac
    done
}

prompt_backup_settings() {
    local retention_value=""

    COMPRESS=false
    ENCRYPT=false
    GPG_PASSPHRASE=""
    GPG_PASSPHRASE_FILE=""
    EXCLUDE_PATTERNS=()
    RETENTION_DAILY=7
    RETENTION_WEEKLY=4
    RETENTION_MONTHLY=3

    echo
    if prompt_yes_no "Enable compression? [Y/n]: " "y"; then
        COMPRESS=true
    fi

    if prompt_yes_no "Enable encryption? [y/N]: " "n"; then
        ENCRYPT=true
        read -r -p "Use a passphrase file instead of typing the passphrase? [y/N]: " retention_value
        if [[ "$retention_value" =~ ^[Yy]$ ]]; then
            read -r -p "Path to passphrase file: " GPG_PASSPHRASE_FILE
        else
            read -r -s -p "Enter GPG passphrase: " GPG_PASSPHRASE
            echo
            [[ -n "$GPG_PASSPHRASE" ]] || die "Encryption passphrase cannot be empty."
        fi
    fi

    if prompt_yes_no "Add rsync exclude patterns? [y/N]: " "n"; then
        echo "Enter one exclude pattern per line. Submit an empty line when done."
        read_paths_into_array EXCLUDE_PATTERNS "Exclude pattern: "
    fi

    read -r -p "Daily retention in days [7]: " retention_value
    RETENTION_DAILY="${retention_value:-7}"
    read -r -p "Weekly retention in weeks [4]: " retention_value
    RETENTION_WEEKLY="${retention_value:-4}"
    read -r -p "Monthly retention in months [3]: " retention_value
    RETENTION_MONTHLY="${retention_value:-3}"
}

###############################################################################
# Backup implementation
###############################################################################
backup_base_name() {
    local name="$1"

    name="${name%.tar.gz.gpg}"
    name="${name%.tar.gpg}"
    name="${name%.tar.gz}"
    name="${name%.tar}"
    name="${name%.gpg}"
    printf '%s\n' "$name"
}

timestamp_to_epoch() {
    local stamp="$1"
    date -u -d "${stamp:0:4}-${stamp:4:2}-${stamp:6:2} ${stamp:9:2}:${stamp:11:2}:${stamp:13:2} UTC" +%s
}

create_lock() {
    LOCK_DIR="${TARGET_DIR%/}/.backup.lock"
    if mkdir -- "$LOCK_DIR" 2>/dev/null; then
        return 0
    fi
    die "Another backup appears to be running for $TARGET_DIR"
}

build_shell_command() {
    local IFS=' '
    local rendered=()
    local arg="" quoted=""

    for arg in "$@"; do
        printf -v quoted '%q' "$arg"
        rendered+=("$quoted")
    done

    printf '%s' "${rendered[*]}"
}

write_metadata() {
    local snapshot_dir="$1"
    local manifest_path="$snapshot_dir/backup_manifest.txt"
    local source=""
    local pattern=""

    {
        printf 'backup_name=%s\n' "$(basename "$snapshot_dir")"
        printf 'created_at_utc=%s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        printf 'host=%s\n' "$HOST_TAG"
        printf 'compress=%s\n' "$COMPRESS"
        printf 'encrypt=%s\n' "$ENCRYPT"
        printf 'retention_daily=%s\n' "$RETENTION_DAILY"
        printf 'retention_weekly=%s\n' "$RETENTION_WEEKLY"
        printf 'retention_monthly=%s\n' "$RETENTION_MONTHLY"
        printf 'sources:\n'
        for source in "${SOURCE_DIRS[@]}"; do
            printf '  - %s\n' "$source"
        done
        if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]]; then
            printf 'excludes:\n'
            for pattern in "${EXCLUDE_PATTERNS[@]}"; do
                printf '  - %s\n' "$pattern"
            done
        fi
    } >"$manifest_path"
}

sync_source() {
    local source="$1"
    local snapshot_dir="$2"
    local relative_path destination_dir parent_dir
    local rsync_args=(--archive --human-readable)
    local pattern=""

    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        rsync_args+=("--exclude=$pattern")
    done

    if [[ -d "$source" ]]; then
        relative_path="${source#/}"
        destination_dir="$snapshot_dir/files/$relative_path"
        mkdir -p -- "$destination_dir"
        log_msg INFO "Backing up directory: $source"
        rsync "${rsync_args[@]}" -- "$source/" "$destination_dir/"
        return 0
    fi

    if [[ -f "$source" ]]; then
        relative_path="${source#/}"
        parent_dir="$snapshot_dir/files/$(dirname "$relative_path")"
        mkdir -p -- "$parent_dir"
        log_msg INFO "Backing up file: $source"
        rsync "${rsync_args[@]}" -- "$source" "$parent_dir/"
        return 0
    fi

    log_msg WARN "Skipping unsupported or missing source: $source"
    return 1
}

package_backup() {
    local snapshot_dir="$1"
    local backup_name="$2"
    local artifact="$snapshot_dir"
    local archive_path="" encrypted_path=""

    if [[ "$COMPRESS" == true || "$ENCRYPT" == true ]]; then
        if [[ "$COMPRESS" == true ]]; then
            archive_path="${TARGET_DIR%/}/${backup_name}.tar.gz"
            CURRENT_ARTIFACT="$archive_path"
            log_msg INFO "Compressing backup to: $archive_path"
            tar -czf "$archive_path" -C "$(dirname "$snapshot_dir")" "$(basename "$snapshot_dir")"
        else
            archive_path="${TARGET_DIR%/}/${backup_name}.tar"
            CURRENT_ARTIFACT="$archive_path"
            log_msg INFO "Packing backup to: $archive_path"
            tar -cf "$archive_path" -C "$(dirname "$snapshot_dir")" "$(basename "$snapshot_dir")"
        fi

        rm -rf -- "$snapshot_dir"
        artifact="$archive_path"
    fi

    if [[ "$ENCRYPT" == true ]]; then
        encrypted_path="${artifact}.gpg"
        CURRENT_ARTIFACT="$encrypted_path"
        log_msg INFO "Encrypting backup to: $encrypted_path"

        if [[ -n "$GPG_PASSPHRASE_FILE" ]]; then
            gpg --batch --yes --pinentry-mode loopback \
                --passphrase-file "$GPG_PASSPHRASE_FILE" \
                --symmetric \
                --output "$encrypted_path" \
                "$artifact"
        else
            gpg --batch --yes --pinentry-mode loopback \
                --passphrase "$GPG_PASSPHRASE" \
                --symmetric \
                --output "$encrypted_path" \
                "$artifact"
        fi

        rm -f -- "$artifact"
        artifact="$encrypted_path"
    fi

    CURRENT_ARTIFACT="$artifact"
}

apply_retention_policy() {
    local target_dir="$1"
    local now_epoch daily_cutoff weekly_cutoff monthly_cutoff
    local item name base_name stamp epoch week_key month_key
    local -a candidates=() entries=()
    declare -A kept_weeks=()
    declare -A kept_months=()

    if (( RETENTION_DAILY == 0 && RETENTION_WEEKLY == 0 && RETENTION_MONTHLY == 0 )); then
        log_msg INFO "Retention disabled; keeping all existing backups."
        return 0
    fi

    now_epoch="$(date -u +%s)"
    daily_cutoff=$(( now_epoch - (RETENTION_DAILY * 86400) ))
    weekly_cutoff=$(( now_epoch - (RETENTION_WEEKLY * 7 * 86400) ))
    monthly_cutoff=$(( now_epoch - (RETENTION_MONTHLY * 31 * 86400) ))

    while IFS= read -r item; do
        [[ -n "$item" ]] && candidates+=("$item")
    done < <(find "$target_dir" -mindepth 1 -maxdepth 1 \( -type f -o -type d \) -name 'backup_*' -printf '%f\n')

    [[ ${#candidates[@]} -gt 0 ]] || return 0

    for name in "${candidates[@]}"; do
        base_name="$(backup_base_name "$name")"
        stamp="${base_name#backup_}"
        stamp="${stamp%%_*}"
        [[ "$stamp" =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || continue
        epoch="$(timestamp_to_epoch "$stamp")"
        entries+=("${epoch}"$'\t'"${name}")
    done

    [[ ${#entries[@]} -gt 0 ]] || return 0

    mapfile -t entries < <(printf '%s\n' "${entries[@]}" | sort -r)

    for item in "${entries[@]}"; do
        epoch="${item%%$'\t'*}"
        name="${item#*$'\t'}"

        if (( RETENTION_DAILY > 0 )) && (( epoch >= daily_cutoff )); then
            continue
        fi

        if (( RETENTION_WEEKLY > 0 )) && (( epoch >= weekly_cutoff )); then
            week_key="$(date -u -d "@$epoch" +%G-%V)"
            if [[ -z "${kept_weeks[$week_key]+x}" ]]; then
                kept_weeks[$week_key]=1
                continue
            fi
        fi

        if (( RETENTION_MONTHLY > 0 )) && (( epoch >= monthly_cutoff )); then
            month_key="$(date -u -d "@$epoch" +%Y-%m)"
            if [[ -z "${kept_months[$month_key]+x}" ]]; then
                kept_months[$month_key]=1
                continue
            fi
        fi

        log_msg INFO "Removing expired backup: ${target_dir%/}/$name"
        rm -rf -- "${target_dir%/}/$name"
    done
}

create_backup() {
    local timestamp backup_name snapshot_dir source copied_count=0

    validate_configuration
    create_lock

    timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
    backup_name="backup_${timestamp}_${HOST_TAG}"
    snapshot_dir="${TARGET_DIR%/}/${backup_name}"
    CURRENT_ARTIFACT="$snapshot_dir"

    mkdir -p -- "$snapshot_dir/files"
    write_metadata "$snapshot_dir"

    for source in "${SOURCE_DIRS[@]}"; do
        if sync_source "$source" "$snapshot_dir"; then
            copied_count=$((copied_count + 1))
        fi
    done

    [[ $copied_count -gt 0 ]] || die "No sources were successfully backed up."

    package_backup "$snapshot_dir" "$backup_name"
    BACKUP_SUCCEEDED=true

    log_msg INFO "Backup created successfully: $CURRENT_ARTIFACT"
    apply_retention_policy "$TARGET_DIR"
}

###############################################################################
# Cron helper
###############################################################################
configure_cron_job() {
    local cron_sources=()
    local cron_excludes=()
    local cron_dest=""
    local cron_compress=false
    local cron_encrypt=false
    local cron_passphrase_file=""
    local cron_daily=7
    local cron_weekly=4
    local cron_monthly=3
    local hour="" minute="" value=""
    local command=("$SCRIPT_PATH" "--auto" "--no-color")
    local cron_line=""

    echo
    echo "Configure cron backup job"
    echo "Enter one source path per line. Submit an empty line when done."
    read_paths_into_array cron_sources "Source path: "
    if [[ ${#cron_sources[@]} -eq 0 ]]; then
        load_default_sources
        cron_sources=("${SOURCE_DIRS[@]}")
    fi

    while [[ -z "$cron_dest" ]]; do
        read -r -p "Destination directory: " cron_dest
    done

    if prompt_yes_no "Enable compression for cron runs? [Y/n]: " "y"; then
        cron_compress=true
    fi

    if prompt_yes_no "Add exclude patterns? [y/N]: " "n"; then
        echo "Enter one exclude pattern per line. Submit an empty line when done."
        read_paths_into_array cron_excludes "Exclude pattern: "
    fi

    if prompt_yes_no "Enable encryption for cron runs? [y/N]: " "n"; then
        cron_encrypt=true
        while [[ -z "$cron_passphrase_file" ]]; do
            read -r -p "Path to passphrase file: " cron_passphrase_file
        done
    fi

    read -r -p "Daily retention in days [7]: " value
    cron_daily="${value:-7}"
    read -r -p "Weekly retention in weeks [4]: " value
    cron_weekly="${value:-4}"
    read -r -p "Monthly retention in months [3]: " value
    cron_monthly="${value:-3}"

    while true; do
        read -r -p "Hour for daily backup [0-23]: " hour
        [[ "$hour" =~ ^([01]?[0-9]|2[0-3])$ ]] && break
        echo "Invalid hour."
    done

    while true; do
        read -r -p "Minute for daily backup [0-59]: " minute
        [[ "$minute" =~ ^([0-5]?[0-9])$ ]] && break
        echo "Invalid minute."
    done

    command+=("--dest" "$cron_dest" "--retention-daily" "$cron_daily" "--retention-weekly" "$cron_weekly" "--retention-monthly" "$cron_monthly")

    if [[ "$cron_compress" == true ]]; then
        command+=("--compress")
    fi

    if [[ "$cron_encrypt" == true ]]; then
        command+=("--encrypt" "--gpg-passphrase-file" "$cron_passphrase_file")
    fi

    for value in "${cron_sources[@]}"; do
        command+=("--source" "$value")
    done

    for value in "${cron_excludes[@]}"; do
        command+=("--exclude" "$value")
    done

    cron_line="${minute} ${hour} * * * $(build_shell_command "${command[@]}")"
    (crontab -l 2>/dev/null || true; printf '%s\n' "$cron_line") | crontab -
    log_msg INFO "Cron job added: $cron_line"
}

###############################################################################
# CLI parsing
###############################################################################
load_defaults_if_needed() {
    [[ ${#SOURCE_DIRS[@]} -gt 0 ]] && return 0
    load_default_sources
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --source)
                [[ -n "${2-}" ]] || die "--source requires a path."
                SOURCE_DIRS+=("$2")
                BACKUP_REQUESTED=true
                shift 2
                ;;
            --dest)
                [[ -n "${2-}" ]] || die "--dest requires a directory."
                TARGET_DIR="$2"
                BACKUP_REQUESTED=true
                shift 2
                ;;
            --exclude)
                [[ -n "${2-}" ]] || die "--exclude requires a pattern."
                EXCLUDE_PATTERNS+=("$2")
                BACKUP_REQUESTED=true
                shift 2
                ;;
            --compress)
                COMPRESS=true
                BACKUP_REQUESTED=true
                shift
                ;;
            --encrypt)
                ENCRYPT=true
                BACKUP_REQUESTED=true
                shift
                ;;
            --gpg-passphrase)
                [[ -n "${2-}" ]] || die "--gpg-passphrase requires a value."
                GPG_PASSPHRASE="$2"
                BACKUP_REQUESTED=true
                shift 2
                ;;
            --gpg-passphrase-file)
                [[ -n "${2-}" ]] || die "--gpg-passphrase-file requires a path."
                GPG_PASSPHRASE_FILE="$2"
                BACKUP_REQUESTED=true
                shift 2
                ;;
            --retention-daily)
                [[ -n "${2-}" ]] || die "--retention-daily requires a value."
                RETENTION_DAILY="$2"
                BACKUP_REQUESTED=true
                shift 2
                ;;
            --retention-weekly)
                [[ -n "${2-}" ]] || die "--retention-weekly requires a value."
                RETENTION_WEEKLY="$2"
                BACKUP_REQUESTED=true
                shift 2
                ;;
            --retention-monthly)
                [[ -n "${2-}" ]] || die "--retention-monthly requires a value."
                RETENTION_MONTHLY="$2"
                BACKUP_REQUESTED=true
                shift 2
                ;;
            --auto)
                AUTO_MODE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --no-color)
                NO_COLOR=true
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done
}

###############################################################################
# Interactive menu
###############################################################################
run_interactive_backup() {
    select_source_directories
    if [[ ${#SOURCE_DIRS[@]} -eq 0 ]]; then
        log_msg WARN "No sources selected. Backup canceled."
        return 0
    fi

    if ! select_target_directory; then
        log_msg WARN "No destination selected. Backup canceled."
        return 0
    fi

    prompt_backup_settings
    create_backup
}

main_menu() {
    local choice=""

    while true; do
        clear
        echo "========================================="
        echo "              Backup Script"
        echo "========================================="
        echo "1) Perform Backup"
        echo "2) Configure Automated Cron Job"
        echo "3) Quit"
        echo
        read -r -p "Enter your choice [1-3]: " choice

        case "$choice" in
            1)
                run_interactive_backup
                press_enter_to_continue
                ;;
            2)
                require_command crontab
                configure_cron_job
                press_enter_to_continue
                ;;
            3)
                echo "Goodbye."
                break
                ;;
            *)
                log_msg WARN "Invalid choice."
                press_enter_to_continue
                ;;
        esac
    done
}

###############################################################################
# Entry point
###############################################################################
parse_args "$@"

if [[ "$AUTO_MODE" == true || "$BACKUP_REQUESTED" == true ]]; then
    load_defaults_if_needed
    create_backup
    exit 0
fi

main_menu
