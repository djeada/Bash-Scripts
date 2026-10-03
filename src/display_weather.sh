#!/usr/bin/env bash

# Script Name: display_weather.sh
# Description: Fetches and displays the current weather for a specified city using wttr.in.
#              Without a city, wttr.in guesses the location from your IP address.
# Usage: ./display_weather.sh [CITY]
# Example: ./display_weather.sh London
#          ./display_weather.sh "New York"

# Function to display usage
usage() {
    echo "Usage: $0 [CITY]" >&2
    exit 1
}

# Check for too many arguments
if [ "$#" -gt 1 ]; then
    usage
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "Error: this script requires 'curl'." >&2
    exit 1
fi

CITY="${1:-}"

# Fetch the weather as "Location: Condition Temperature" (wttr.in expects '+' for spaces),
# making curl follow any redirects and fail on HTTP errors.
if ! WEATHER_DATA=$(curl -fsSL -G --data-urlencode "format=%l: %C %t" "https://wttr.in/${CITY// /+}"); then
    echo "Error: failed to fetch weather data for '${CITY:-your location}'." >&2
    exit 1
fi

# Parsing the data (the condition text follows the first ':')
CONDITION="${WEATHER_DATA#*:}"

# Display the City Name
echo -e "\e[1m\e[95mCity: ${CITY:-auto-detected}\e[0m"
echo "-----------------------------------"

# Use a case statement to display the appropriate weather icon and color
shopt -s nocasematch
case $CONDITION in
    *Clear*|*Sunny*)
        echo -e "\e[93m☀️ $WEATHER_DATA\e[0m"
        ;;
    *Rain*|*Drizzle*|*Shower*)
        echo -e "\e[94m🌧️ $WEATHER_DATA\e[0m"
        ;;
    *Snow*|*Sleet*|*Ice*)
        echo -e "\e[96m❄️ $WEATHER_DATA\e[0m"
        ;;
    *Cloud*|*Overcast*)
        echo -e "\e[37m☁️ $WEATHER_DATA\e[0m"
        ;;
    *)
        echo -e "\e[95m🌀 $WEATHER_DATA\e[0m" # Default case
        ;;
esac
echo "-----------------------------------"

