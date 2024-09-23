#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Color codes for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to ensure a command exists, if not, install it
function ensure_installed() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${GREEN}$1 not found. Installing...${NC}"
        pip install "$1"
    fi
}

# Function to build the package
function build_package() {
    echo -e "${GREEN}Building distribution packages...${NC}"
    ensure_installed build
    python -m build
}

# Function to upload to TestPyPI
function upload_testpypi() {
    echo -e "${GREEN}Uploading to TestPyPI...${NC}"
    twine upload --repository testpypi dist/*
    echo -e "${GREEN}Package uploaded to TestPyPI.${NC}"
    echo -e "${GREEN}You can install it using:${NC}"
    echo "pip install --index-url https://test.pypi.org/simple/ --no-deps your-package-name"
}

# Function to upload to PyPI
function upload_pypi() {
    echo -e "${GREEN}Uploading to PyPI...${NC}"
    twine upload dist/*
    echo -e "${GREEN}Package uploaded to PyPI.${NC}"
}

# Function to check for uncommitted changes
function check_git_status() {
    if [ -n "$(git status --porcelain)" ]; then
        echo -e "${GREEN}Uncommitted changes detected. Please commit or stash them before releasing.${NC}"
        exit 1
    fi
}

# Function to confirm the package version
function confirm_version() {
    PACKAGE_VERSION=$(python setup.py --version)
    echo -e "${GREEN}Current package version is: $PACKAGE_VERSION${NC}"
    read -p "Is this the correct version to upload? (y/n): " confirm_version
    if [ "$confirm_version" != "y" ]; then
        echo -e "${GREEN}Please update your package version before proceeding.${NC}"
        exit 1
    fi
}

# Main script execution
function main() {
    # Check for uncommitted changes
    check_git_status

    # Ensure required tools are installed
    ensure_installed twine

    # Build the package
    build_package

    # Optionally upload to TestPyPI
    read -p "Do you want to upload to TestPyPI first? (y/n): " upload_test
    if [ "$upload_test" = "y" ]; then
        upload_testpypi
    fi

    # Confirm version before uploading to PyPI
    confirm_version

    # Upload to PyPI
    read -p "Ready to upload to PyPI. Proceed? (y/n): " upload_pypi
    if [ "$upload_pypi" = "y" ]; then
        upload_pypi
    else
        echo -e "${GREEN}Upload to PyPI aborted.${NC}"
    fi

    echo -e "${GREEN}Script completed.${NC}"
}

# Run the main function
main
