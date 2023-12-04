#!/usr/bin/env bash

# Script Name: empty_trash.sh
# Description: Empties the trash directory.
# Usage: empty_trash.sh [-p path] [-l log_file] [-v]
# Example: empty_trash.sh -p ~/.Trash

LOG_FILE="/var/log/empty_trash.log"
LOG_ENABLED=0
VERBOSE=0
TRASH_PATH=""

function log_action {
    [ $LOG_ENABLED -eq 1 ] && echo "$(date +"%Y-%m-%d %T"): $1" >> $LOG_FILE
}

function print_usage {
    echo "Usage: $0 [-p path_to_trash] [-l log_file] [-v]"
    echo "  -p: specify trash directory path"
    echo "  -l: enable logging to a specified log file"
    echo "  -v: verbose mode"
}

function confirm_deletion {
    read -p "Are you sure you want to empty the trash? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

while getopts ":p:l:v" opt; do
    case $opt in
        p)
            TRASH_PATH=$OPTARG
            ;;
        l)
            LOG_FILE=$OPTARG
            LOG_ENABLED=1
            ;;
        v)
            VERBOSE=1
            ;;
        \?)
            print_usage
            exit 1
            ;;
    esac
done

# Default trash path for Linux and MacOS
if [ -z "$TRASH_PATH" ]; then
    if [ "$(uname)" == "Darwin" ]; then
        TRASH_PATH=~/.Trash
        [ $VERBOSE -eq 1 ] && echo "Detected system: Mac OS X"
    elif [ "$(uname)" == "Linux" ]; then
        TRASH_PATH=~/.local/share/Trash/files
        [ $VERBOSE -eq 1 ] && echo "Detected system: Linux"
    else
        echo "Unsupported system. Please specify the trash path."
        exit 1
    fi
fi

if [ -d "$TRASH_PATH" ]; then
    if [ -w "$TRASH_PATH" ]; then
        if confirm_deletion; then
            rm -rf "${TRASH_PATH:?}"/* && echo "Trash emptied successfully" || echo "Failed to empty trash"
            log_action "Trash emptied successfully"
        else
            echo "Trash emptying cancelled."
            log_action "Trash emptying cancelled by user."
        fi
    else
        echo "You do not have write permissions to the trash directory."
        exit 1
    fi
else
    echo "The specified trash directory does not exist."
    exit 1
fi
