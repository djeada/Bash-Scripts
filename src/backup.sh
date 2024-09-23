#!/usr/bin/env bash

# Script Name: backup.sh
# Description: Create a backup of the specified directory based on a configuration file.
# Supports compression, encryption, and backup retention policies.
# Usage: backup.sh [-c config_file] [-v]
#        If not provided, the default configuration file is used.

set -euo pipefail
IFS=$'\n\t'

trap cleanup INT TERM EXIT

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

DEFAULT_CONFIG_FILE="config.sh"
CURRENT_BACKUP_FILE=""
VERBOSE=0

cleanup() {
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
        return
    fi

    if [[ "$?" -ne 0 ]]; then
        log ERROR "Script encountered an error. Cleaning up..."
    else
        log INFO "Script completed successfully."
    fi

    if [[ -n "${CURRENT_BACKUP_FILE:-}" && -f "${CURRENT_BACKUP_FILE}" ]]; then
        log INFO "Removing incomplete backup file: ${CURRENT_BACKUP_FILE}"
        rm -f "${CURRENT_BACKUP_FILE}"
    fi

    exit 1
}

log() {
    local level="$1"
    shift
    local message="$*"

    case "$level" in
        ERROR)
            echo -e "${RED}[ERROR] $message${NC}" >&2
            ;;
        WARN)
            echo -e "${RED}[WARN] $message${NC}"
            ;;
        INFO)
            if [[ "${VERBOSE}" -ge 0 ]]; then
                echo -e "${GREEN}[INFO] $message${NC}"
            fi
            ;;
        DEBUG)
            if [[ "${VERBOSE}" -ge 1 ]]; then
                echo -e "[DEBUG] $message"
            fi
            ;;
    esac
}

check_dependencies() {
    local dependencies=("rsync" "tar" "gpg" "date")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            log ERROR "$dep is required but not installed. Aborting."
            exit 1
        fi
    done
}

validate_config_file() {
    local config_file="$1"
    # shellcheck source=/dev/null
    source "$config_file"

    local variables=("BACKUP_DIR" "SOURCE_DIR" "WITH_COMPRESSION" "WITH_ENCRYPTION")
    for var in "${variables[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log ERROR "Variable $var is not set in config file."
            exit 1
        fi
    done

    if [[ "${WITH_ENCRYPTION}" == "true" ]] && [[ -z "${GPG_PASSPHRASE:-}" ]]; then
        log ERROR "GPG_PASSPHRASE is required for encryption but not set."
        exit 1
    fi

    echo "${EXCLUDE_DIRS[@]:-}" >/dev/null # Force arrays to be initialized

    log INFO "Configuration validation complete."
}

create_config_file() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
        log WARN "Config file already exists at: $config_file. Not overwriting."
        return
    fi

    log INFO "Creating default config file at: $config_file"

    cat << 'EOF' > "$config_file"
# Backup configuration file

# Backup directory path where the backup will be stored.
BACKUP_DIR="/path/to/backup/dir"

# Source directory path that needs to be backed up.
SOURCE_DIR="/path/to/source/dir"

# Array of directories to exclude from the backup.
EXCLUDE_DIRS=()

# Array of specific files to exclude from the backup.
EXCLUDE_FILES=()

# Array of file extensions to exclude from the backup.
EXCLUDE_EXTENSIONS=()

# Set to 'true' to enable backup compression, 'false' to disable.
WITH_COMPRESSION=true

# Set to 'true' to enable backup encryption, 'false' to disable.
WITH_ENCRYPTION=false

# Passphrase for encryption. Required if WITH_ENCRYPTION is set to true.
GPG_PASSPHRASE="your_passphrase_here"

# Number of days to keep backups. Backups older than this will be deleted.
BACKUP_RETENTION_DAYS=7
EOF

    log INFO "Config file created at $config_file"
}

compress_backup() {
    local backup_file="$1"
    log INFO "Compressing backup file: $backup_file"
    tar -czf "${backup_file}.tar.gz" -C "$(dirname "$backup_file")" "$(basename "$backup_file")"
    rm -rf "$backup_file"
    CURRENT_BACKUP_FILE="${backup_file}.tar.gz"
    log INFO "Compression complete."
}

encrypt_backup() {
    local backup_file="$1"
    log INFO "Encrypting backup file: $backup_file"
    echo "${GPG_PASSPHRASE}" | gpg --batch --yes --passphrase-fd 0 --symmetric "$backup_file"
    rm -f "$backup_file"
    CURRENT_BACKUP_FILE="${backup_file}.gpg"
    log INFO "Encryption complete."
}

clean_old_backups() {
    log INFO "Cleaning backups older than ${BACKUP_RETENTION_DAYS} days."
    find "${BACKUP_DIR}" -type f -mtime +"${BACKUP_RETENTION_DAYS}" -name 'backup_*' -exec rm -f {} \;
    log INFO "Old backups cleaned."
}

create_backup() {
    log INFO "Creating backup..."
    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local backup_filename="backup_${timestamp}"
    local backup_filepath="${BACKUP_DIR}/${backup_filename}"
    CURRENT_BACKUP_FILE="$backup_filepath"

    mkdir -p "${BACKUP_DIR}"

    # Build rsync exclude parameters
    local rsync_exclude_params=()
    for dir in "${EXCLUDE_DIRS[@]:-}"; do
        rsync_exclude_params+=(--exclude="$dir")
    done
    for file in "${EXCLUDE_FILES[@]:-}"; do
        rsync_exclude_params+=(--exclude="$file")
    done
    for ext in "${EXCLUDE_EXTENSIONS[@]:-}"; do
        rsync_exclude_params+=(--exclude="*${ext}")
    done

    if ! rsync -a "${rsync_exclude_params[@]}" "${SOURCE_DIR}/" "${backup_filepath}/"; then
        log ERROR "Error during rsync. Aborting."
        exit 1
    fi

    if [[ "${WITH_COMPRESSION}" == "true" ]]; then
        compress_backup "$backup_filepath"
    fi

    if [[ "${WITH_ENCRYPTION}" == "true" ]]; then
        encrypt_backup "${CURRENT_BACKUP_FILE}"
    fi

    log INFO "Backup created successfully at ${CURRENT_BACKUP_FILE}"

    if [[ "${BACKUP_RETENTION_DAYS:-0}" -gt 0 ]]; then
        clean_old_backups
    fi
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -c CONFIG_FILE   Specify configuration file to use. Defaults to config.sh
  -v               Enable verbose output
  -h               Show this help message and exit
EOF
}

main() {
    local config_file="$DEFAULT_CONFIG_FILE"

    while getopts ":c:vh" opt; do
        case $opt in
            c)
                config_file="$OPTARG"
                ;;
            v)
                VERBOSE=1
                ;;
            h)
                usage
                exit 0
                ;;
            \?)
                log ERROR "Invalid option: -$OPTARG"
                usage
                exit 1
                ;;
            :)
                log ERROR "Option -$OPTARG requires an argument."
                usage
                exit 1
                ;;
        esac
    done

    check_dependencies

    if [[ ! -f "$config_file" ]]; then
        if [[ "$config_file" != "$DEFAULT_CONFIG_FILE" ]]; then
            log ERROR "Config file not found: $config_file"
            exit 1
        else
            create_config_file "$config_file"
            log INFO "Please edit the config file with desired values and run the script again."
            exit 1
        fi
    fi

    log INFO "Using config file: $config_file"
    validate_config_file "$config_file"
    create_backup
}

main "$@"
