#!/usr/bin/env bash

# Script Name: commit_date_modifier.sh
# Description: Modifies the date of the latest Git commit to a user-provided date
# Usage: commit_date_modifier.sh DD-MM-YYYY
#        The date is in the format day-month-year
# Example: commit_date_modifier.sh 25-12-2022

# Function: Returns absolute value of a number
abs() {
    echo ${1#-}
}

# Function: Convert the input date into a weekday string
day_string_converter() {
    local day=$1
    local month=$2
    local year=$3

    # Zeller's Congruence algorithm for calculating the day of the week
    local a=$(( (14 - month) / 12 ))
    local y=$(( year - a ))
    local m=$(( month + (12 * a) - 2 ))
    local d=$(( (day + y + (y / 4) - (y / 100) + (y / 400) + ((31 * m) / 12)) % 7 ))

    local days=("Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat")

    echo "${days[d]}"
}

# Function: Convert numeric month into a month string
month_string_converter() {
    local month_strs=("Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")

    echo "${month_strs[$1-1]}"
}

# Function: Generate a random time string in the format HH:MM
random_time() {
    printf -v time "%02d:%02d" $((RANDOM % 24)) $((RANDOM % 60))
    echo "$time"
}

# Function: Validate the input date format
validate_date() {
    if [[ $1 =~ ^([1-9]|0[1-9]|[12][0-9]|3[01])-(0[1-9]|1[0-2])-([0-9]{4})$ ]]; then
        IFS='-' read -r day month year <<< "$1"
        # Check the date validity
        if ! date -d"$month/$day/$year" >/dev/null 2>&1; then
            echo "Invalid date: $1"
            exit 1
        fi
    else
        echo "Incorrect date format: $1. Expected format: DD-MM-YYYY"
        exit 1
    fi
}

# Function: Main function to control the script flow
main() {
    if [ $# -ne 1 ]; then
        echo "Error: No arguments provided."
        echo "Usage: commit_date_modifier.sh DD-MM-YYYY"
        echo "       The date is in the format day-month-year."
        echo "Example: commit_date_modifier.sh 25-12-2022"
        exit 1
    fi

    local date="$1"
    validate_date "$date"
    IFS='-' read -r day month year <<< "$date"
    local day_string=$(day_string_converter "$day" "$month" "$year")
    local month_string=$(month_string_converter "$month")
    local time_string=$(random_time)

    GIT_COMMITTER_DATE="$day_string $month_string $day $time_string $year +0100" git commit --amend --no-edit --date "$day_string $month_string $day $time_string $year +0100"
    echo "Commit date modified to $day_string $month_string $day $time_string $year"
}

main "$@"

