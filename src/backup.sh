#!/usr/bin/env bash

# Script Name: backup.sh
# Description: Create a backup of the provided directory based on a configuration file.
# Usage: backup.sh  <config_file>
#        <config_file> is the path to the configuration file.
#        If not provided, the default configuration file is created.

set -e
trap cleanup INT

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

cleanup() {
    echo -e "${RED}Script interrupted. Cleaning up...${NC}"
    # Add any cleanup operations here.
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
    echo "Creating a default config file at: $1"

    cat << EOF > "$1"
BACKUP_DIR=path/to/backup/dir
SOURCE_DIR=path/to/source/dir
EXCLUDE_DIRS=()
EXCLUDE_FILES=()
EXCLUDE_EXTENSIONS=()
WITH_COMPRESSION=true
WITH_ENCRYPTION=false
GPG_PASSPHRASE=passphrase
EOF

    echo "Config file created"
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

    mkdir -p "${BACKUP_DIR}"

    rsync -av --exclude-from="${EXCLUDE_DIRS}" --exclude-from="${EXCLUDE_FILES}" --exclude-from="${EXCLUDE_EXTENSIONS}" "${SOURCE_DIR}" "${BACKUP_DIR}"

    if [ "${WITH_COMPRESSION}" = true ]; then
        compress_backup
    fi

    if [ "${WITH_ENCRYPTION}" = true ]; then
        encrypt_backup
    fi

    echo -e "${GREEN}Backup created${NC}"
}

main() {
    check_dependencies

    if [ $# -eq 0 ]; then
        default_config_file="config.sh"
        create_config_file $default_config_file
        echo "Fill the config file with the desired values and run the script again."
        exit 1
    fi

    if [ -f "$1" ]; then
        echo "Using config file: $1"
        validate_config_file "$1"
        create_backup
    else
        echo -e "${RED}Config file not found: $1${NC}"
        exit 1
    fi
}

main "$@"

