#!/usr/bin/env bash

# Script Name: youtube_to_mp3.sh
# Description: Downloads the audio of a YouTube video (or every video of a playlist)
#              and converts it to MP3 format using yt-dlp and ffmpeg.
#              Files are named after the video title (spaces become underscores).
#              If yt-dlp/ffmpeg are missing, offers to install them (apt/pacman, needs sudo).
# Usage: ./youtube_to_mp3.sh <youtube_url> [output_directory]
#        output_directory defaults to the current directory.
# Example: ./youtube_to_mp3.sh https://www.youtube.com/watch?v=example ./music

DEPENDENCIES=("yt-dlp" "ffmpeg")

check_dependencies() {
    local dependency
    for dependency in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dependency" >/dev/null 2>&1; then
            echo "Error: '$dependency' is not installed." >&2
            return 1
        fi
    done
    return 0
}

try_to_install_dependencies() {
    local -a command_to_install
    local dependency

    if [ ! -f /etc/os-release ]; then
        echo "Error: /etc/os-release not found" >&2
        return 1
    fi

    if grep -q "debian" /etc/os-release; then
        command_to_install=(apt install)
    elif grep -q "arch" /etc/os-release; then
        command_to_install=(pacman -S)
    else
        echo "Error: Unknown OS; please install ${DEPENDENCIES[*]} manually." >&2
        return 1
    fi

    for dependency in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dependency" >/dev/null 2>&1; then
            echo "Trying to install '$dependency'."
            sudo "${command_to_install[@]}" "$dependency"
        fi
    done
}

# Download one video's audio as "<output_dir>/<title>.mp3".
download_video_and_convert_to_mp3() {
    local url="$1"
    local output_dir="$2"
    echo "Downloading audio from '$url' to '$output_dir'"
    yt-dlp --no-playlist --extract-audio --audio-format mp3 --audio-quality 128K \
        --restrict-filenames --paths "$output_dir" --output "%(title)s.%(ext)s" "$url"
}

main() {
    if [ $# -lt 1 ] || [ $# -gt 2 ]; then
        echo "Usage: youtube_to_mp3.sh <youtube_url> [output_directory]" >&2
        return 1
    fi

    local url="$1"
    local output_dir="${2:-.}"

    if ! check_dependencies; then
        try_to_install_dependencies
        if ! check_dependencies; then
            echo "Error: Dependencies not installed." >&2
            return 1
        fi
    fi

    if ! mkdir -p -- "$output_dir"; then
        echo "Error: cannot create output directory '$output_dir'." >&2
        return 1
    fi

    local -a all_videos_urls
    mapfile -t all_videos_urls < <(yt-dlp --flat-playlist --print "%(id)s" "$url" | sed 's_^_https://youtu.be/_')

    if [ "${#all_videos_urls[@]}" -eq 0 ]; then
        echo "Error: No videos found at '$url'." >&2
        return 1
    fi

    local failures=0 video_url
    if [ "${#all_videos_urls[@]}" -gt 1 ]; then
        echo "Downloading playlist (${#all_videos_urls[@]} videos)..."
        for video_url in "${all_videos_urls[@]}"; do
            download_video_and_convert_to_mp3 "$video_url" "$output_dir" || failures=$((failures + 1))
        done
    else
        download_video_and_convert_to_mp3 "$url" "$output_dir" || failures=1
    fi

    if [ "$failures" -gt 0 ]; then
        echo "Error: $failures download(s) failed." >&2
        return 1
    fi
}

main "$@"

