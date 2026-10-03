#!/usr/bin/env bash

# Script Name: make_short.sh
# Description: Robust 9:16 Shorts encoder with safe auto-crop for creating vertical video shorts.
#              Requires ffmpeg, ffprobe, and awk.
# Usage: ./make_short.sh -i INPUT -o OUTPUT [options]
# Options:
#   -i, --input PATH             Input video (required).
#   -o, --output PATH            Output video (required).
#   --crop auto|manual|none      Crop mode (default: auto).
#   --fit shortsmart|pad|stretch|cropfill  Fit mode (default: shortsmart).
# Example: ./make_short.sh -i input.mp4 -o output.mp4

set -euo pipefail

# Force dot decimal separator regardless of OS locale
export LC_NUMERIC=C
export LC_ALL=C
export LANG=C

usage() {
    cat <<EOF
Usage: $0 -i INPUT -o OUTPUT [options]

Required:
  -i, --input PATH             Input video
  -o, --output PATH            Output video

Crop:
  --crop auto                  Auto-detect black borders (SAFE; won't overcrop)
  --crop manual:L:T:R:B        Manually crop by pixels (Left,Top,Right,Bottom)
  --crop none                  Disable all cropping
  --probe-seconds S            Seconds to analyze for auto-crop (default: 6)

Fit/Output:
  --fit shortsmart|pad|stretch|cropfill
      shortsmart (default): remove black bars, then crop to exact 9:16 safely, then scale 1080x1920
      pad:        keep AR, center with black bars as needed (1080x1920 canvas)
      stretch:    force 1080x1920 (distorts)
      cropfill:   same crop-to-9:16 path as shortsmart (kept for compatibility)

Safety margin:
  --safe-left N               Left black margin in final 1080x1920 output (px). Default: 30. Use 0 to disable.

Encoding:
  --fps N                      Output fps (default: 25)
  --speed auto|X.Y             Speed factor > 0 (default: auto = max(1.0, dur/max-seconds))
  --max-seconds S              Hard cap duration (default: 59)
  --crf N                      x264 CRF (default: 18)
  --preset NAME                x264 preset (default: veryfast)

Flags:
  --exact-crop true|false      Apply :exact=1 to crop filter (default: false)
  --debug                      Print built ffmpeg command
  -h, --help                   Show this help
EOF
    exit "${1:-1}"
}

die() {
    echo "Error: $*" >&2
    exit 1
}

# Value of an option that requires one ($1 = option name, $2 = value)
need_arg() {
    [[ -n "${2:-}" ]] || die "Option $1 requires a value."
}

is_number() {
    [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

INPUT=""
OUTPUT=""
CROP_MODE="auto"     # default to auto now
CROP_SPEC=""
FIT="shortsmart"
FPS="25"
SPEED="auto"
MAXS="59"
CRF="18"
PRESET="veryfast"
PROBE_S="6"
EXACT_CROP="false"
DEBUG="false"
SAFE_LEFT="30"

# --- Parse args ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage 0 ;;
        --debug) DEBUG="true"; shift; continue ;;
        -i|--input|-o|--output|--crop|--fit|--fps|--speed|--max-seconds|--crf|--preset|--probe-seconds|--exact-crop|--safe-left)
            need_arg "$1" "${2:-}" ;;
        *) echo "Unknown arg: $1" >&2; usage >&2 ;;
    esac
    case "$1" in
        -i|--input) INPUT="$2" ;;
        -o|--output) OUTPUT="$2" ;;
        --crop)
            case "$2" in
                auto|none) CROP_MODE="$2" ;;
                manual:*) CROP_MODE="manual"; CROP_SPEC="${2#manual:}" ;;
                *) die "Invalid --crop value: $2" ;;
            esac
            ;;
        --fit) FIT="$2" ;;
        --fps) FPS="$2" ;;
        --speed) SPEED="$2" ;;
        --max-seconds) MAXS="$2" ;;
        --crf) CRF="$2" ;;
        --preset) PRESET="$2" ;;
        --probe-seconds) PROBE_S="$2" ;;
        --exact-crop) EXACT_CROP="$2" ;;
        --safe-left) SAFE_LEFT="$2" ;;
    esac
    shift 2
done

[[ -z "$INPUT" || -z "$OUTPUT" ]] && usage >&2
[[ -f "$INPUT" ]] || die "Input not found: $INPUT"

case "$FIT" in
    shortsmart|pad|stretch|cropfill) ;;
    *) die "Invalid --fit: $FIT" ;;
esac
[[ "$SPEED" == "auto" ]] || { is_number "$SPEED" && awk -v s="$SPEED" 'BEGIN{exit !(s>0)}'; } || die "--speed must be 'auto' or a number > 0"
{ is_number "$MAXS" && awk -v m="$MAXS" 'BEGIN{exit !(m>0.2)}'; } || die "--max-seconds must be a number > 0.2"
is_number "$FPS" || die "--fps must be a number"
is_number "$PROBE_S" || die "--probe-seconds must be a number"
[[ "$CRF" =~ ^[0-9]+$ ]] || die "--crf must be an integer"
[[ "$SAFE_LEFT" =~ ^[0-9]+$ ]] || die "--safe-left must be a non-negative integer"
[[ "$EXACT_CROP" == "true" || "$EXACT_CROP" == "false" ]] || die "--exact-crop must be true or false"

for cmd in ffmpeg ffprobe awk; do
    command -v "$cmd" >/dev/null || die "$cmd not found"
done

# --- Helpers (numeric) ---
get_dims() {
    ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
        -of csv=p=0 "$1"           # outputs: 1920,1080
}
floor_even() {
    LC_ALL=C awk -v x="$1" 'BEGIN{ y=int(x/2)*2; if (y<0) y=0; print y }'
}
clamp() { # x min max
    LC_ALL=C awk -v x="$1" -v a="$2" -v b="$3" 'BEGIN{ if(x<a) x=a; if(x>b) x=b; print x }'
}

# --- cropdetect (stable, conservative) ---
# Use modest threshold, small rounding so we don't lose content.
# We take the LAST suggested crop within PROBE_S (usually stable for bars).
# cropdetect reports at "info" log level, so ffmpeg must not run with -v error.
autodetect_crop_whxy() {
    ffmpeg -hide_banner -nostats -i "$INPUT" -t "$PROBE_S" \
        -vf "cropdetect=24:2:1" -f null - 2>&1 \
        | sed -n 's/.*crop=\([0-9]\+:[0-9]\+:[0-9]\+:[0-9]\+\).*/\1/p' \
        | tail -n 1
}

# --- SAFE 9:16 crop synthesizer ---
# Inputs: source iw,ih and optional detected crop w,h,x,y
# Output: FINAL evenized w:h:x:y that:
#   - is 9:16 (width shrunk if too wide, height shrunk if too tall), centered
#   - stays inside the frame
synthesize_safe_916_crop() {
    local iw="$1" ih="$2" det="$3"
    local w h x y
    if [[ -n "$det" ]]; then
        IFS=':' read -r w h x y <<< "$det"
    else
        w="$iw"; h="$ih"; x=0; y=0
    fi

    # Minimum width to preserve exact 9:16 from the cropped height
    local wmin
    wmin=$(LC_ALL=C awk -v H="$h" 'BEGIN{print H*9/16.0}')
    wmin="$(floor_even "$wmin")"
    if [[ "$wmin" -lt 2 ]]; then wmin=2; fi

    # If detected width is wider than 9:16, shrink to 9:16 and center horizontally
    if (( w > wmin )); then
        local dx
        dx=$(LC_ALL=C awk -v W="$w" -v WM="$wmin" 'BEGIN{print (W-WM)/2.0}')
        x=$(LC_ALL=C awk -v X="$x" -v DX="$dx" 'BEGIN{print X+DX}')
        w="$wmin"
    elif (( w < wmin )); then
        # Too tall for 9:16 (e.g. portrait sources): shrink height and center vertically
        local hmax dy
        hmax="$(floor_even "$(LC_ALL=C awk -v W="$w" 'BEGIN{print W*16/9.0}')")"
        if (( hmax >= 2 && hmax < h )); then
            dy=$(LC_ALL=C awk -v H="$h" -v HM="$hmax" 'BEGIN{print (H-HM)/2.0}')
            y=$(LC_ALL=C awk -v Y="$y" -v DY="$dy" 'BEGIN{print Y+DY}')
            h="$hmax"
        fi
    fi

    # Evenize and clamp to frame
    w="$(floor_even "$w")"
    h="$(floor_even "$h")"
    x="$(floor_even "$x")"
    y="$(floor_even "$y")"

    # Ensure the rect is in-bounds after rounding
    local maxx maxy
    maxx=$(( iw - w )); maxy=$(( ih - h ))
    x="$(clamp "$x" 0 "$maxx")"
    y="$(clamp "$y" 0 "$maxy")"

    echo "${w}:${h}:${x}:${y}"
}

# --- Manual crop (L:T:R:B -> w:h:x:y) with evenization ---
manual_to_whxy() {
    local iw="$1" ih="$2" L="$3" T="$4" R="$5" B="$6"
    local v
    for v in "$L" "$T" "$R" "$B"; do
        [[ "$v" =~ ^[0-9]+$ ]] || return 1
    done
    local w=$(( iw - L - R ))
    local h=$(( ih - T - B ))
    local x="$L" y="$T"
    w="$(floor_even "$w")"; h="$(floor_even "$h")"; x="$(floor_even "$x")"; y="$(floor_even "$y")"
    if (( w<2 || h<2 )); then echo ""; return 1; fi
    echo "${w}:${h}:${x}:${y}"
}

# --- Compute auto speed factor if requested ---
DUR="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$INPUT" | LC_ALL=C awk '{printf("%.6f\n",$1)}')"
if [[ "$SPEED" == "auto" ]]; then
    SPEED="$(LC_ALL=C awk -v d="$DUR" -v m="$MAXS" 'BEGIN{f=d/m; if(f<1.0) f=1.0; printf("%.8f",f)}')"
fi
echo "Computed speed factor: $SPEED"; LC_ALL=C awk -v s="$SPEED" 'BEGIN{if(s>16) print "Warning: very high speed factor (" s "x)" > "/dev/stderr"}'

# --- Build filter graph ---
IFS=',' read -r IW IH <<<"$(get_dims "$INPUT")"
[[ "$IW" =~ ^[0-9]+$ && "$IH" =~ ^[0-9]+$ ]] || die "Could not read video dimensions of $INPUT"

vf_chain=()
CROP_SUFFIX=""; [[ "$EXACT_CROP" == "true" ]] && CROP_SUFFIX=":exact=1"

# Normalize and validate left safety margin for final canvas
SAFE_LEFT="$(clamp "${SAFE_LEFT}" 0 1078)"
SAFE_LEFT="$(floor_even "${SAFE_LEFT}")" # keep even for yuv420 alignment
TARGET_WIDTH=$(( 1080 - SAFE_LEFT ))
if (( TARGET_WIDTH < 2 )); then
    die "--safe-left too large; resulting width < 2"
fi

case "$CROP_MODE" in
    auto)
        DET="$(autodetect_crop_whxy || true)"
        if [[ "$FIT" == "shortsmart" || "$FIT" == "cropfill" ]]; then
            SAFE="$(synthesize_safe_916_crop "$IW" "$IH" "${DET:-}")"
            vf_chain+=("crop=${SAFE}${CROP_SUFFIX}")
        else
            # For pad/stretch, only remove detected black bars; don't force 9:16 crop.
            if [[ -n "$DET" ]]; then
                vf_chain+=("crop=${DET}${CROP_SUFFIX}")
            fi
        fi
        ;;
    manual)
        IFS=':' read -r L T R B <<< "$CROP_SPEC"
        : "${L:?Missing L}"; : "${T:?Missing T}"; : "${R:?Missing R}"; : "${B:?Missing B}"
        MAN="$(manual_to_whxy "$IW" "$IH" "$L" "$T" "$R" "$B")" || die "Manual crop must be manual:L:T:R:B (pixels) leaving a valid window"
        if [[ "$FIT" == "shortsmart" || "$FIT" == "cropfill" ]]; then
            # For portrait fill, ensure 9:16 width from the MAN height
            SAFE="$(synthesize_safe_916_crop "$IW" "$IH" "$MAN")"
            vf_chain+=("crop=${SAFE}${CROP_SUFFIX}")
        else
            vf_chain+=("crop=${MAN}${CROP_SUFFIX}")
        fi
        ;;
    none)
        # Explicitly disable cropping.
        ;;
esac

# Fit to 9:16 frame
case "$FIT" in
    shortsmart|cropfill)
        vf_chain+=("scale=1080:1920:force_divisible_by=2")
        ;;
    pad)
        vf_chain+=("scale=1080:1920:force_original_aspect_ratio=decrease:force_divisible_by=2")
        vf_chain+=("pad=1080:1920:floor((ow-iw)/2):floor((oh-ih)/2)")
        ;;
    stretch)
        vf_chain+=("scale=1080:1920:force_divisible_by=2")
        ;;
esac

# Apply left safety margin without covering or cropping content:
# - scale to fit within (1080 - SAFE_LEFT) x 1920 preserving AR
# - then pad to 1080x1920 with left offset SAFE_LEFT and vertical centering
if (( SAFE_LEFT > 0 )); then
    vf_chain+=("scale=${TARGET_WIDTH}:1920:force_original_aspect_ratio=decrease:force_divisible_by=2")
    vf_chain+=("pad=1080:1920:${SAFE_LEFT}:floor((oh-ih)/2)")
fi

# Pixel/Display aspect
vf_chain+=("setsar=1")
vf_chain+=("setdar=9/16")

# Speed + fps
vf_chain+=("setpts=PTS/${SPEED}")
vf_chain+=("fps=${FPS}")

VIDEO_LABEL="[v]"
AUDIO_LABEL="[a]"
FILTER_COMPLEX="[0:v]$(IFS=,; echo "${vf_chain[*]}")${VIDEO_LABEL}"

# Build an atempo chain for speed factor $1 (each atempo stage must be within 0.5..2.0)
build_atempo_chain() {
    local f="$1" chain=()
    while LC_ALL=C awk -v x="$f" 'BEGIN{exit !(x>2.0000001)}'; do
        chain+=("atempo=2.0")
        f="$(LC_ALL=C awk -v x="$f" 'BEGIN{printf("%.8f", x/2.0)}')"
    done
    while LC_ALL=C awk -v x="$f" 'BEGIN{exit !(x<0.4999999)}'; do
        chain+=("atempo=0.5")
        f="$(LC_ALL=C awk -v x="$f" 'BEGIN{printf("%.8f", x*2.0)}')"
    done
    chain+=("atempo=$(LC_ALL=C awk -v x="$f" 'BEGIN{printf("%.8f",x)}')")
    (IFS=,; echo "${chain[*]}")
}

# Audio
AUDIO_ARGS=()
if ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$INPUT" | grep -q .; then
    ATEMPO_CHAIN="$(build_atempo_chain "$SPEED")"
    FILTER_COMPLEX="${FILTER_COMPLEX};[0:a]${ATEMPO_CHAIN}${AUDIO_LABEL}"
    AUDIO_ARGS=(-map "${AUDIO_LABEL}" -c:a aac -b:a 128k)
else
    AUDIO_ARGS=(-an)
fi

# Cap duration slightly under the limit
CAP="$(LC_ALL=C awk -v m="$MAXS" 'BEGIN{printf("%.3f",m-0.2)}')"

FFCMD=( ffmpeg -y -noautorotate -i "$INPUT"
    -filter_complex "$FILTER_COMPLEX"
    -map "${VIDEO_LABEL}" "${AUDIO_ARGS[@]}"
    -c:v libx264 -preset "$PRESET" -crf "$CRF" -pix_fmt yuv420p
    -metadata:s:v:0 rotate=0 -map_metadata -1 -movflags +faststart
    -t "$CAP"
    "$OUTPUT"
)

if [[ "$DEBUG" == "true" ]]; then
    echo "[debug] filter_complex: $FILTER_COMPLEX"
    printf "[debug] cmd:"; printf " %q" "${FFCMD[@]}"; echo
fi

"${FFCMD[@]}"

# Report
NEW_DUR="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$OUTPUT" | LC_ALL=C awk '{printf("%.6f\n",$1)}' || echo "n/a")"
echo "Done."
echo "Input ${IW}x${IH}, duration ${DUR}s"
echo "Speed factor   : ${SPEED}x"
echo "Output duration: ${NEW_DUR}s (capped at ${CAP}s)"
echo "Output file    : ${OUTPUT}"

