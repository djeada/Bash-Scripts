#!/bin/bash

# Script Description:
# This script safely uninstalls all user-installed Python packages globally via pip,
# keeping essential system packages intact.

essential_packages=("pip" "setuptools" "wheel")
backup_dir="$HOME/python_package_backups"
backup_file="$backup_dir/backup_$(date +%Y%m%d%H%M%S).txt"

purge_package() {
    local package="$1"
    echo "Purging non-essential package: $package"
    pip uninstall -y "$package"
    if [[ $? -eq 0 ]]; then
        echo "Successfully purged: $package"
    else
        echo "Error: Failed to purge $package"
    fi
}

if ! command -v pip &>/dev/null; then
    echo "Error: 'pip' is not installed globally."
    exit 1
fi

mkdir -p "$backup_dir"

installed_packages=$(pip freeze | cut -d'=' -f1 | grep -vE "($(IFS="|"; echo "${essential_packages[*]}"))")

echo "$installed_packages" > "$backup_file"
echo "Backup of installed packages created at $backup_file"

for package in $installed_packages; do
    purge_package "$package"
done

echo "Global package purge completed."
