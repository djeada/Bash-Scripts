#!/usr/bin/env bash

# Script Name: release_package.sh
# Description: Automates the process of building, checking, and releasing a Python package to PyPI or TestPyPI.
#
# Usage: ./release_package.sh [options]
#
# Options:
#   -h, --help                   Show this help message and exit.
#   -t, --test                   Upload the package to TestPyPI.
#   -p, --production             Upload the package to PyPI.
#   -s, --skip-tests             Skip running tests before building.
#   -v, --version VERSION        Specify the package version to release.
#   -n, --name NAME              Specify the package name.
#   -c, --config FILE            Specify a configuration file with default settings.
#   -e, --env VENV_PATH          Specify a virtual environment to use.
#   -i, --interpreter PATH       Specify the Python interpreter to use.
#   --dry-run                    Perform a dry run without uploading.
#
# Examples:
#   ./release_package.sh --test
#   ./release_package.sh --production --version 1.0.0 --name my-package
#   ./release_package.sh --config release.conf --production

set -euo pipefail

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
UPLOAD_TO_TEST=false
UPLOAD_TO_PROD=false
SKIP_TESTS=false
PACKAGE_VERSION=""
PACKAGE_NAME=""
CONFIG_FILE=""
VENV_PATH=""
PYTHON_INTERPRETER="python"
DRY_RUN=false

# Function to display help message
function show_help() {
    grep '^#' "$0" | cut -c 4-
    exit 0
}

# Function to ensure a Python package is installed
function ensure_python_package() {
    local package="$1"
    if ! "$PYTHON_INTERPRETER" -c "import $package" &> /dev/null; then
        echo -e "${GREEN}Installing Python package '$package'...${NC}"
        "$PYTHON_INTERPRETER" -m pip install --upgrade "$package"
    fi
}

# Function to run tests
function run_tests() {
    if [ -f "setup.py" ]; then
        echo -e "${GREEN}Running tests...${NC}"
        "$PYTHON_INTERPRETER" setup.py test
    elif [ -f "pytest.ini" ] || [ -d "tests" ]; then
        echo -e "${GREEN}Running pytest...${NC}"
        ensure_python_package pytest
        "$PYTHON_INTERPRETER" -m pytest
    else
        echo -e "${RED}No tests found.${NC}"
    fi
}

# Function to build the package
function build_package() {
    echo -e "${GREEN}Building distribution packages...${NC}"
    ensure_python_package build
    rm -rf dist/ build/
    "$PYTHON_INTERPRETER" -m build
}

# Function to check the built package
function check_package() {
    echo -e "${GREEN}Checking distribution packages...${NC}"
    ensure_python_package twine
    "$PYTHON_INTERPRETER" -m twine check dist/*
}

# Function to upload to TestPyPI
function upload_testpypi() {
    echo -e "${GREEN}Uploading to TestPyPI...${NC}"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${GREEN}[Dry Run] Skipping upload to TestPyPI.${NC}"
    else
        "$PYTHON_INTERPRETER" -m twine upload --repository testpypi dist/*
        echo -e "${GREEN}Package uploaded to TestPyPI.${NC}"
        if [ -n "$PACKAGE_NAME" ]; then
            echo -e "${GREEN}You can install it using:${NC}"
            echo "pip install --index-url https://test.pypi.org/simple/ --no-deps $PACKAGE_NAME"
        fi
    fi
}

# Function to upload to PyPI
function upload_pypi() {
    echo -e "${GREEN}Uploading to PyPI...${NC}"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${GREEN}[Dry Run] Skipping upload to PyPI.${NC}"
    else
        "$PYTHON_INTERPRETER" -m twine upload dist/*
        echo -e "${GREEN}Package uploaded to PyPI.${NC}"
    fi
}

# Function to check for uncommitted changes
function check_git_status() {
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        if [ -n "$(git status --porcelain)" ]; then
            echo -e "${RED}Uncommitted changes detected. Please commit or stash them before releasing.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Not a git repository. Skipping git status check.${NC}"
    fi
}

# Function to confirm the package version
function confirm_version() {
    local version
    if [ -n "$PACKAGE_VERSION" ]; then
        version="$PACKAGE_VERSION"
    else
        version=$("$PYTHON_INTERPRETER" setup.py --version 2>/dev/null || echo "Unknown")
    fi
    echo -e "${GREEN}Current package version is: $version${NC}"
    read -r -p "Is this the correct version to upload? (y/n): " confirm_version
    if [ "$confirm_version" != "y" ]; then
        echo -e "${RED}Please update your package version before proceeding.${NC}"
        exit 1
    fi
}

# Function to parse the configuration file
function parse_config() {
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${GREEN}Loading configuration from $CONFIG_FILE...${NC}"
        while IFS='=' read -r key value; do
            case "$key" in
                upload_to_test) UPLOAD_TO_TEST="$value" ;;
                upload_to_prod) UPLOAD_TO_PROD="$value" ;;
                skip_tests) SKIP_TESTS="$value" ;;
                package_version) PACKAGE_VERSION="$value" ;;
                package_name) PACKAGE_NAME="$value" ;;
                python_interpreter) PYTHON_INTERPRETER="$value" ;;
                venv_path) VENV_PATH="$value" ;;
                dry_run) DRY_RUN="$value" ;;
            esac
        done < "$CONFIG_FILE"
    else
        echo -e "${RED}Configuration file $CONFIG_FILE not found.${NC}"
        exit 1
    fi
}

# Parse command-line arguments
function parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -t|--test)
                UPLOAD_TO_TEST=true
                shift
                ;;
            -p|--production)
                UPLOAD_TO_PROD=true
                shift
                ;;
            -s|--skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            -v|--version)
                PACKAGE_VERSION="$2"
                shift 2
                ;;
            -n|--name)
                PACKAGE_NAME="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -e|--env)
                VENV_PATH="$2"
                shift 2
                ;;
            -i|--interpreter)
                PYTHON_INTERPRETER="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                ;;
        esac
    done
}

# Function to activate virtual environment if specified
function activate_virtualenv() {
    if [ -n "$VENV_PATH" ]; then
        if [ -d "$VENV_PATH" ]; then
            source "$VENV_PATH/bin/activate"
            PYTHON_INTERPRETER="$VENV_PATH/bin/python"
            echo -e "${GREEN}Using virtual environment at $VENV_PATH${NC}"
        else
            echo -e "${RED}Virtual environment at $VENV_PATH not found.${NC}"
            exit 1
        fi
    fi
}

# Main script execution
function main() {
    parse_args "$@"

    # Parse configuration file if specified
    if [ -n "$CONFIG_FILE" ]; then
        parse_config
    fi

    # Activate virtual environment if specified
    activate_virtualenv

    # Check for uncommitted changes
    check_git_status

    # Ensure required tools are installed
    ensure_python_package pip
    ensure_python_package setuptools
    ensure_python_package wheel
    ensure_python_package twine

    # Run tests unless skipped
    if [ "$SKIP_TESTS" = false ]; then
        run_tests
    fi

    # Build the package
    build_package

    # Check the built package
    check_package

    # Confirm version before uploading
    confirm_version

    # Upload to TestPyPI or PyPI
    if [ "$UPLOAD_TO_TEST" = true ]; then
        upload_testpypi
    fi

    if [ "$UPLOAD_TO_PROD" = true ]; then
        upload_pypi
    fi

    if [ "$UPLOAD_TO_TEST" = false ] && [ "$UPLOAD_TO_PROD" = false ]; then
        echo -e "${GREEN}Build completed. Packages are available in the 'dist/' directory.${NC}"
    fi

    echo -e "${GREEN}Script completed.${NC}"
}

# Run the main function
main "$@"
