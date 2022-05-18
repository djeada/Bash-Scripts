#!/usr/bin/env bash

# Script Name: backup.sh
# Description: Create a backup of the provided directory.
# Usage: backup.sh  <config_file>
#        <config_file> is the path to the configuration file. If not provided,
#        the default configuration file is created and the script has to be executed again.
# Usage: ./backup.sh path/to/config_file

validate_config_file() {
    source "$1"

    if [ -z "${BACKUP_DIR}" ]; then
        echo "BACKUP_DIR is not set"
        exit 1
    fi

    if [ -z "${SOURCE_DIR}" ]; then
        echo "SOURCE_DIR is not set"
        exit 1
    fi

    if [ -z "${EXCLUDE_DIRS}" ]; then
        echo "EXCLUDE_DIRS is not set"
        exit 1
    fi

    if [ -z "${EXCLUDE_FILES}" ]; then
        echo "EXCLUDE_FILES is not set"
        exit 1
    fi

    if [ -z "${EXCLUDE_EXTENSIONS}" ]; then
        echo "EXCLUDE_EXTENSIONS is not set"
        exit 1
    fi

    if [ -z "${WITH_COMPRESSION}" ]; then
        echo "WITH_COMPRESSION is not set"
        exit 1
    fi

    if [ -z "${WITH_ENCRYPTION}" ]; then
        echo "WITH_ENCRYPTION is not set"
        exit 1
    fi

    if [ -z "${GPG_PASSPHRASE}" ]; then
        echo "GPG_PASSPHRASE is not set"
        exit 1
    fi

    echo "Validation complete"
}

create_config_file() {
    echo "Creating a defualt config file at: $1"

    echo "BACKUP_DIR=path/to/backup/dir" > "$1"
    echo "SOURCE_DIR=path/to/source/dir" >> "$1"
    echo "EXCLUDE_DIRS=0" >> "$1"
    echo "EXCLUDE_FILES=0" >> "$1"
    echo "EXCLUDE_EXTENSIONS=0" >> "$1"
    echo "WITH_COMPRESSION=true" >> "$1"
    echo "WITH_ENCRYPTION=true" >> "$1"
    echo "GPG_PASSPHRASE=passphrase" >> "$1"

    echo "Config file created"
}

create_backup() {
    echo "Creating backup"

    if [ ! -d "${BACKUP_DIR}" ]; then
        mkdir -p "${BACKUP_DIR}"
    fi

    if [ ! -d "${SOURCE_DIR}" ]; then
        echo "Source directory does not exist"
        exit 1
    fi

    # copy all files and directories from source to backup
    rsync -av --exclude-from="${EXCLUDE_DIRS}" --exclude-from="${EXCLUDE_FILES}" --exclude-from="${EXCLUDE_EXTENSIONS}" "${SOURCE_DIR}" "${BACKUP_DIR}"

    if [ "${WITH_COMPRESSION}" == "true" ]; then
        echo "Compressing backup"
        tar -czf "../${BACKUP_DIR}/backup.tar.gz" "${BACKUP_DIR}"
        echo "Compression complete"

        if [ "${WITH_ENCRYPTION}" == "true" ]; then
            echo "Encrypting backup"
            gpg --batch --yes --passphrase="${GPG_PASSPHRASE}" --symmetric "../${BACKUP_DIR}/backup.tar.gz"
            echo "Encryption complete"
        fi
        # remove uncompressed backup
        rm -rf "${BACKUP_DIR}"
    fi

    echo "Backup created"
}

main() {

    if [ $# -eq 0 ]; then
        default_config_file="config.sh"
        create_config_file $default_config_file
        echo "Fill the config file with the desired values and run the script again."
        exit 1
    fi
    
    if [ -f "$1" ]; then
        echo "Using config file: $1"
        validate_config_file "$1"
        create_backup "$1"
    else
        echo "Config file not found: $1"
        exit 1
    fi
    
}

main "$@"

