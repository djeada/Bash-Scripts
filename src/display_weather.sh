#!/usr/bin/env bash

# Script Name: display_weather.sh
# Description: Fetches and displays the current weather for a specified city using wttr.in.
# Usage: ./display_weather.sh [CITY]
# Example: ./display_weather.sh London

# Function to display usage
usage() {
    echo "Usage: $0 [CITY]"
    exit 1
}

# Check for missing arguments
if [ "$#" -ne 1 ]; then
    usage
fi

# Define your city
CITY="$1"

# Fetch the weather data, making curl follow any redirects
WEATHER_DATA=$(curl -s -L "http://wttr.in/$CITY?format=3")

# Parsing the data
CONDITION=$(echo "$WEATHER_DATA" | awk -F ':' '{print $2}')

# Display the City Name
echo -e "\e[1m\e[95mCity: $CITY\e[0m"
echo "-----------------------------------"

# Use a case statement to display the appropriate weather icon and color
case $CONDITION in
    *Clear*)
        echo -e "\e[93m☀️ $WEATHER_DATA\e[0m"
        ;;
    *Rain*|*Drizzle*)
        echo -e "\e[94m🌧️ $WEATHER_DATA\e[0m"
        ;;
    *Cloud*)
        echo -e "\e[37m☁️ $WEATHER_DATA\e[0m"
        ;;
    *Snow*)
        echo -e "\e[96m❄️ $WEATHER_DATA\e[0m"
        ;;
    *)
        echo -e "\e[95m🌀 $WEATHER_DATA\e[0m" # Default case
        ;;
esac
echo "-----------------------------------"

