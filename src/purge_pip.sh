#!/bin/bash

# Script Description:
# This Bash script is designed to purge (uninstall and remove) all user-installed
# Python packages via pip, while retaining essential packages that are part of
# the standard Python installation. It identifies non-essential packages installed
# by the user and removes them, preserving the integrity of essential packages.

# List of essential packages
essential_packages=("pip" "setuptools" "wheel")

# Function to uninstall and remove a package
purge_package() {
    local package="$1"
    pip uninstall -y "$package"
    pip uninstall -y "$package" # Uninstall twice to ensure removal
}

# Check if pip is installed
if ! command -v pip &>/dev/null; then
    echo "Error: 'pip' is not installed."
    exit 1
fi

# List all installed packages via pip, excluding the essential ones
installed_packages=$(pip freeze | cut -d'=' -f1 | grep -vE "($(IFS="|"; echo "${essential_packages[*]}"))")

# Purge non-essential packages
for package in $installed_packages; do
    echo "Purging non-essential package: $package"
    purge_package "$package"

    # Check the uninstallation status
    if [[ $? -eq 0 ]]; then
        echo "Successfully purged: $package"
    else
        echo "Error: Failed to purge $package"
    fi
done

echo "Package purge completed."
