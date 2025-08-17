#!/usr/bin/env bash
set -euo pipefail

# Force dot decimal separator regardless of OS locale
export LC_NUMERIC=C
export LC_ALL=C
export LANG=C

# make_short.sh — turn any video into a YouTube Short/IG Reel–ready file.
# Requires: ffmpeg, ffprobe, awk
#
# Examples:
#   # Auto-crop, pad to 9:16, auto speed-up to <=59s
#   ./make_short.sh -i input.mp4 -o short.mp4 --crop auto --fit pad
#
#   # Manual crop (50 left, 20 top, 600 right, 0 bottom), crop-to-fill 9:16, force 3.5×
#   ./make_short.sh -i input.mp4 -o short.mp4 --crop manual:50:20:600:0 --fit cropfill --speed 3.5
#
#   # Stretch to 1080x1920 (no padding), auto speed-up, 30 fps
#   ./make_short.sh -i input.mp4 -o short.mp4 --fit stretch --fps 30

usage() {
  cat <<EOF
Usage: $0 -i INPUT -o OUTPUT [options]

Required:
  -i, --input PATH             Input video
  -o, --output PATH            Output video

Optional:
  --crop auto                  Auto-detect black borders via cropdetect
  --crop manual:L:T:R:B        Manually crop by pixels from Left,Top,Right,Bottom
  --fit pad|stretch|cropfill   How to fit into 9:16 frame (default: pad)
                                - pad: keep AR, center with black bars if needed
                                - stretch: force 1080x1920 (stretches image)
                                - cropfill: crop to fill 9:16, then scale
  --fps N                      Output fps (default: 25)
  --speed auto|X.Y             Speed-up factor (default: auto)
                               auto => factor = max(1.0, duration/59.0)
  --max-seconds S              Hard cap duration (default: 59)
  --crf N                      x264 CRF (default: 18)
  --preset NAME                x264 preset (default: veryfast)
  --probe-seconds S            Seconds to analyze for auto-crop (default: 6)
  -h, --help                   Show this help
EOF
  exit 1
}

INPUT=""
OUTPUT=""
CROP_MODE="none"     # none|auto|manual
CROP_SPEC=""         # L:T:R:B when manual
FIT="pad"            # pad|stretch|cropfill
FPS="25"
SPEED="auto"
MAXS="59"
CRF="18"
PRESET="veryfast"
PROBE_S="6"

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--input) INPUT="${2:-}"; shift 2 ;;
    -o|--output) OUTPUT="${2:-}"; shift 2 ;;
    --crop)
      if [[ "${2:-}" == "auto" ]]; then CROP_MODE="auto"; shift 2
      elif [[ "${2:-}" =~ ^manual: ]]; then CROP_MODE="manual"; CROP_SPEC="${2#manual:}"; shift 2
      else echo "Invalid --crop value"; exit 1; fi ;;
    --fit) FIT="${2:-}"; shift 2 ;;
    --fps) FPS="${2:-}"; shift 2 ;;
    --speed) SPEED="${2:-}"; shift 2 ;;
    --max-seconds) MAXS="${2:-}"; shift 2 ;;
    --crf) CRF="${2:-}"; shift 2 ;;
    --preset) PRESET="${2:-}"; shift 2 ;;
    --probe-seconds) PROBE_S="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

[[ -z "$INPUT" || -z "$OUTPUT" ]] && usage
[[ ! -f "$INPUT" ]] && { echo "Input not found: $INPUT"; exit 1; }

# --- Dependency checks ---
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg not found"; exit 1; }
command -v ffprobe >/dev/null 2>&1 || { echo "ffprobe not found"; exit 1; }
command -v awk >/dev/null 2>&1 || { echo "awk not found"; exit 1; }

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# --- Helper: get duration (seconds, float) ---
get_duration() {
  ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$1" \
    | LC_ALL=C awk '{printf("%.6f\n",$1)}'
}

# --- Helper: detect if audio stream exists ---
has_audio() {
  local n
  n="$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$1" | wc -l | LC_ALL=C awk '{print $1}')"
  [[ "$n" -ge 1 ]]
}

# --- Helper: build atempo chain for factor >1 (speed-up) using chunks <=2.0 ---
# Input: factor (e.g., 3.5) -> "atempo=2.0,atempo=1.75"
build_atempo_chain() {
  local f="$1" chain=()
  # clamp small numerical noise
  f="$(LC_ALL=C awk -v x="$f" 'BEGIN{if (x<1.000001) x=1.0; printf("%.8f",x)}')"
  while LC_ALL=C awk -v x="$f" 'BEGIN{exit !(x>2.0000001)}'; do
    chain+=("atempo=2.0")
    f="$(LC_ALL=C awk -v x="$f" 'BEGIN{printf("%.8f", x/2.0)}')"
  done
  chain+=("atempo=$(LC_ALL=C awk -v x="$f" 'BEGIN{printf("%.8f",x)}')")
  (IFS=,; echo "${chain[*]}")
}

# --- Helper: auto-crop using cropdetect; returns "w:h:x:y" or empty ---
auto_crop() {
  # Analyze a short segment; grab the last suggested crop
  local line
  line="$(ffmpeg -v error -i "$INPUT" -t "$PROBE_S" \
    -vf "cropdetect=24:16:0" -f null - 2>&1 \
    | sed -n 's/.*crop=\([0-9]\+:[0-9]\+:[0-9]\+:[0-9]\+\).*/\1/p' \
    | tail -n 1)"
  echo "$line"
}

# --- Helper: manual crop from L:T:R:B to crop=w:h:x:y ---
manual_crop() {
  local L="$1" T="$2" R="$3" B="$4"
  echo "iw-${L}-${R}:ih-${T}-${B}:${L}:${T}"
}

# --- Compute auto speed factor if requested ---
DUR="$(get_duration "$INPUT")"
if [[ "$SPEED" == "auto" ]]; then
  # factor = max(1.0, DUR / MAXS)
  SPEED="$(LC_ALL=C awk -v d="$DUR" -v m="$MAXS" 'BEGIN{f=d/m; if(f<1.0) f=1.0; printf("%.8f",f)}')"
fi

# Bonus: print computed speed and warn if extreme
echo "Computed speed factor: $SPEED"
if LC_ALL=C awk -v s="$SPEED" 'BEGIN{exit !(s>16)}'; then
  echo "Warning: very high speed factor (${SPEED})x"
fi

# --- Build filter graph ---
vf_chain=()

# 1) Optional crop
case "$CROP_MODE" in
  auto)
    CROP_STR="$(auto_crop)"
    if [[ -n "$CROP_STR" ]]; then
      vf_chain+=("crop=${CROP_STR}")
    else
      echo "Auto-crop: no crop detected (continuing without cropping)."
    fi
    ;;
  manual)
    IFS=':' read -r L T R B <<< "$CROP_SPEC"
    : "${L:?Missing L}"; : "${T:?Missing T}"; : "${R:?Missing R}"; : "${B:?Missing B}"
    vf_chain+=("crop=$(manual_crop "$L" "$T" "$R" "$B")")
    ;;
  *) : ;;
esac

# 2) Fit to 9:16 — ensure even dimensions to avoid 1px asymmetry
case "$FIT" in
  pad)
    # Keep AR, fit width to 1080, height auto (even), then pad to 1080x1920 with symmetric integer offsets
    vf_chain+=("scale=1080:-2:force_original_aspect_ratio=decrease:force_divisible_by=2")
    vf_chain+=("pad=1080:1920:floor((ow-iw)/2):floor((oh-ih)/2)")
    ;;
  stretch)
    # Force full-frame; keep even just in case
    vf_chain+=("scale=1080:1920:force_divisible_by=2")
    ;;
  cropfill)
    # Crop to 9:16, then scale to exact 1080x1920 (even)
    vf_chain+=("crop=min(iw\\,ih*9/16):min(ih\\,iw*16/9)")
    vf_chain+=("scale=1080:1920:force_divisible_by=2")
    ;;
  *)
    echo "Invalid --fit: $FIT"; exit 1 ;;
esac

# 3) Pixel aspect only (no setdar needed when raster is 1080x1920)
vf_chain+=("setsar=1:1")

# 4) Speed-up video (setpts) + fps
vf_chain+=("setpts=PTS/${SPEED}")
vf_chain+=("fps=${FPS}")

VIDEO_LABEL="[v]"
AUDIO_LABEL="[a]"
FILTER_COMPLEX=""

# Join video filters
FILTER_COMPLEX="${FILTER_COMPLEX}[0:v]$(IFS=,; echo "${vf_chain[*]}")${VIDEO_LABEL}"

# Audio chain if present
MAP_AUDIO=""
AUDIO_FILTERS=""
if has_audio "$INPUT"; then
  # Build atempo chain for SPEED
  ATEMPO_CHAIN="$(build_atempo_chain "$SPEED")"
  AUDIO_FILTERS="[0:a]${ATEMPO_CHAIN}${AUDIO_LABEL}"
  FILTER_COMPLEX="${FILTER_COMPLEX};${AUDIO_FILTERS}"
  MAP_AUDIO="-map ${AUDIO_LABEL} -c:a aac -b:a 128k"
else
  MAP_AUDIO="-an"
fi

# --- Safety: cap duration to MAXS-0.2 to avoid rounding drift at ingest ---
CAP="$(LC_ALL=C awk -v m="$MAXS" 'BEGIN{printf("%.3f",m-0.2)}')"  # e.g., 58.8s

# --- Run ffmpeg ---
# yuv420p + +faststart for best compatibility/ingest
# Also clear any stray rotation/clean-aperture/qt atoms and strip container metadata.
ffmpeg -y -noautorotate -i "$INPUT" \
  -filter_complex "$FILTER_COMPLEX" \
  -map "${VIDEO_LABEL}" $MAP_AUDIO \
  -c:v libx264 -preset "$PRESET" -crf "$CRF" -pix_fmt yuv420p \
  -metadata:s:v:0 rotate=0 -map_metadata -1 -movflags +faststart \
  -t "$CAP" \
  "$OUTPUT"

# --- Report ---
NEW_DUR="$(get_duration "$OUTPUT" || echo "n/a")"
echo "Done."
echo "Input duration : ${DUR}s"
echo "Speed factor   : ${SPEED}x"
echo "Output duration: ${NEW_DUR}s (capped at ${CAP}s)"
echo "Output file    : ${OUTPUT}"
