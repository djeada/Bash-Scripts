#!/usr/bin/env bash

# Script Name: backup.sh
# Description: Create a backup of the provided directory based on a configuration file.
# Usage: backup.sh <config_file>
#        <config_file> is the path to the configuration file.
#        If not provided, the default configuration file is used.

set -e
trap cleanup INT

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
DEFAULT_CONFIG_FILE="config.sh"

cleanup() {
    echo -e "${RED}Script interrupted. Cleaning up...${NC}"

    if [[ -n "${BACKUP_DIR}" ]]; then
        echo "Removing incomplete backup files in ${BACKUP_DIR}"
        find "${BACKUP_DIR}" -name 'backup_*' -mmin -5 -delete
    fi

    # Add any additional cleanup operations here.

    exit 1
}


check_dependencies() {
    dependencies=("rsync" "tar" "gpg")

    for i in "${dependencies[@]}"; do
        command -v "$i" >/dev/null 2>&1 || { echo -e "${RED}$i is required but it's not installed. Aborting.${NC}" >&2; exit 1; }
    done
}

validate_config_file() {
    # SC1090: ShellCheck can't follow non-constant source. Use a directive to specify location.
    # shellcheck source=/dev/null
    source "$1"

    variables=("BACKUP_DIR" "SOURCE_DIR" "EXCLUDE_DIRS" "EXCLUDE_FILES" "EXCLUDE_EXTENSIONS" "WITH_COMPRESSION" "WITH_ENCRYPTION" "GPG_PASSPHRASE")

    for i in "${variables[@]}"; do
        if [ -z "${!i}" ]; then
            echo -e "${RED}$i is not set${NC}"
            exit 1
        fi
    done

    echo -e "${GREEN}Validation complete${NC}"
}

create_config_file() {
    config_file="$1"
    if [ -f "$config_file" ]; then
        echo -e "${RED}Config file already exists at: $config_file. Not overwriting.${NC}"
        return
    fi

    echo "Creating a default config file at: $config_file"

    cat << EOF > "$config_file"
# Backup directory path where the backup will be stored.
BACKUP_DIR=/path/to/backup/dir

# Source directory path that needs to be backed up.
SOURCE_DIR=/path/to/source/dir

# Array of directories to exclude from the backup. Format: ('dir1' 'dir2')
EXCLUDE_DIRS=()

# Array of specific files to exclude from the backup. Format: ('file1' 'file2')
EXCLUDE_FILES=()

# Array of file extensions to exclude from the backup. Format: ('.ext1' '.ext2')
EXCLUDE_EXTENSIONS=()

# Set to 'true' to enable backup compression, 'false' to disable.
WITH_COMPRESSION=true

# Optional: Set to 'true' to enable backup encryption, 'false' to disable.
WITH_ENCRYPTION=false

# Optional: Passphrase for encryption. Required if WITH_ENCRYPTION is set to true.
GPG_PASSPHRASE=your_passphrase_here
EOF

    echo "Config file created at $config_file"
}

compress_backup() {
    echo "Compressing backup"
    tar -czf "${BACKUP_DIR}/backup_$(date +%Y%m%d%H%M%S).tar.gz" -C "${BACKUP_DIR}" .
    echo -e "${GREEN}Compression complete${NC}"
}

encrypt_backup() {
    echo "Encrypting backup"
    gpg --batch --yes --passphrase="${GPG_PASSPHRASE}" --symmetric "${BACKUP_DIR}/backup_$(date +%Y%m%d%H%M%S).tar.gz"
    echo -e "${GREEN}Encryption complete${NC}"
}

create_backup() {
    echo "Creating backup"
    backup_filename="backup_$(date -u +%Y-%m-%dT%H:%M:%SZ).tar.gz"
    mkdir -p "${BACKUP_DIR}"

    # Convert array to rsync exclude format
    for dir in "${EXCLUDE_DIRS[@]}"; do
        rsync_exclude_params+=" --exclude=$dir"
    done

    if ! rsync -av $rsync_exclude_params --exclude-from="${EXCLUDE_FILES}" --exclude-from="${EXCLUDE_EXTENSIONS}" "${SOURCE_DIR}" "${BACKUP_DIR}"; then
        echo -e "${RED}Error during rsync. Aborting.${NC}"
        exit 1
    fi

    if [ "${WITH_COMPRESSION}" = true ]; then
        compress_backup "$backup_filename"
    fi

    if [ "${WITH_ENCRYPTION}" = true ]; then
        encrypt_backup "$backup_filename"
    fi

    echo -e "${GREEN}Backup created${NC}"
}

main() {
    check_dependencies

    config_file="${1:-$DEFAULT_CONFIG_FILE}"
    if [ ! -f "$config_file" ]; then
        if [ "$1" ]; then
            echo -e "${RED}Config file not found: $1${NC}"
            exit 1
        else
            if [ -f "$DEFAULT_CONFIG_FILE" ]; then
                echo -e "${RED}Default config file already exists. Please edit it and rerun the script.${NC}"
                exit 1
            fi
            create_config_file "$DEFAULT_CONFIG_FILE"
            echo "Fill the config file with the desired values and run the script again."
            exit 1
        fi
    fi

    echo "Using config file: $config_file"
    validate_config_file "$config_file"
    create_backup
}

main "$@"
