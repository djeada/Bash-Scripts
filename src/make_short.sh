#!/usr/bin/env bash
set -euo pipefail

# Force dot decimal separator regardless of OS locale
export LC_NUMERIC=C
export LC_ALL=C
export LANG=C

# make_short.sh — robust 9:16 Shorts encoder with SAFE auto-crop.
# Requires: ffmpeg, ffprobe, awk

usage() {
  cat <<EOF
Usage: $0 -i INPUT -o OUTPUT [options]

Required:
  -i, --input PATH             Input video
  -o, --output PATH            Output video

Crop:
  --crop auto                  Auto-detect black borders (SAFE; won't overcrop)
  --crop manual:L:T:R:B        Manually crop by pixels (Left,Top,Right,Bottom)
  --probe-seconds S            Seconds to analyze for auto-crop (default: 6)

Fit/Output:
  --fit shortsmart|pad|stretch|cropfill
      shortsmart (default): remove black bars, then crop to exact 9:16 safely, then scale 1080x1920
      pad:        keep AR, center with black bars as needed (1080x1920 canvas)
      stretch:    force 1080x1920 (distorts)
      cropfill:   crop to fill 9:16 using centered math, then scale (no safety clamp)

Encoding:
  --fps N                      Output fps (default: 25)
  --speed auto|X.Y             Speed-up factor (default: auto = max(1.0, dur/59))
  --max-seconds S              Hard cap duration (default: 59)
  --crf N                      x264 CRF (default: 18)
  --preset NAME                x264 preset (default: veryfast)

Flags:
  --exact-crop true|false      Apply :exact=1 to crop filter (default: false)
  --debug                      Print built ffmpeg command
  -h, --help                   Show this help
EOF
  exit 1
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
    --exact-crop) EXACT_CROP="${2:-false}"; shift 2 ;;
    --debug) DEBUG="true"; shift 1 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

[[ -z "$INPUT" || -z "$OUTPUT" ]] && usage
[[ ! -f "$INPUT" ]] && { echo "Input not found: $INPUT"; exit 1; }

command -v ffmpeg >/dev/null || { echo "ffmpeg not found"; exit 1; }
command -v ffprobe >/dev/null || { echo "ffprobe not found"; exit 1; }
command -v awk >/dev/null || { echo "awk not found"; exit 1; }

tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT

# --- Helpers (numeric) ---
get_dims() {
  ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
    -of csv=s=x:p=0 "$1"
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
autodetect_crop_whxy() {
  ffmpeg -v error -i "$INPUT" -t "$PROBE_S" \
    -vf "cropdetect=24:2:1" -f null - 2>&1 \
    | sed -n 's/.*crop=\([0-9]\+:[0-9]\+:[0-9]\+:[0-9]\+\).*/\1/p' \
    | tail -n 1
}

# --- SAFE 9:16 crop synthesizer ---
# Inputs: source iw,ih and optional detected crop w,h,x,y
# Output: FINAL evenized w:h:x:y that:
#   - never narrower than floor_even(h*9/16)
#   - stays inside the frame
#   - centered if we need to shrink width to 9:16
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
echo "Computed speed factor: $SPEED"; LC_ALL=C awk -v s="$SPEED" 'BEGIN{if(s>16) print "Warning: very high speed factor (" s "x)"}'

# --- Build filter graph ---
read IW IH <<<"$(get_dims "$INPUT")"

vf_chain=()
CROP_SUFFIX=""; [[ "$EXACT_CROP" == "true" ]] && CROP_SUFFIX=":exact=1"

case "$CROP_MODE" in
  auto)
    DET="$(autodetect_crop_whxy || true)"
    SAFE="$(synthesize_safe_916_crop "$IW" "$IH" "${DET:-}")"
    vf_chain+=("crop=${SAFE}${CROP_SUFFIX}")
    ;;
  manual)
    IFS=':' read -r L T R B <<< "$CROP_SPEC"
    : "${L:?Missing L}"; : "${T:?Missing T}"; : "${R:?Missing R}"; : "${B:?Missing B}"
    MAN="$(manual_to_whxy "$IW" "$IH" "$L" "$T" "$R" "$B")" || { echo "Manual crop produced invalid window"; exit 1; }
    if [[ "$FIT" == "shortsmart" || "$FIT" == "cropfill" ]]; then
      # For portrait fill, ensure 9:16 width from the MAN height
      SAFE="$(synthesize_safe_916_crop "$IW" "$IH" "$MAN")"
      vf_chain+=("crop=${SAFE}${CROP_SUFFIX}")
    else
      vf_chain+=("crop=${MAN}${CROP_SUFFIX}")
    fi
    ;;
  *)  # none
    if [[ "$FIT" == "shortsmart" || "$FIT" == "cropfill" ]]; then
      # No bars removal requested; derive 9:16 from full frame
      SAFE="$(synthesize_safe_916_crop "$IW" "$IH" "${IW}:${IH}:0:0")"
      vf_chain+=("crop=${SAFE}${CROP_SUFFIX}")
    fi
    ;;
esac

# Fit to 9:16 frame
case "$FIT" in
  shortsmart|cropfill)
    vf_chain+=("scale=1080:1920:force_divisible_by=2")
    ;;
  pad)
    vf_chain+=("scale=1080:-2:force_original_aspect_ratio=decrease:force_divisible_by=2")
    vf_chain+=("pad=1080:1920:floor((ow-iw)/2):floor((oh-ih)/2)")
    ;;
  stretch)
    vf_chain+=("scale=1080:1920:force_divisible_by=2")
    ;;
  *) echo "Invalid --fit: $FIT"; exit 1 ;;
esac

# Pixel/Display aspect
vf_chain+=("setsar=1")
vf_chain+=("setdar=9/16")

# Speed + fps
vf_chain+=("setpts=PTS/${SPEED}")
vf_chain+=("fps=${FPS}")

VIDEO_LABEL="[v]"
AUDIO_LABEL="[a]"
FILTER_COMPLEX="[0:v]$(IFS=,; echo "${vf_chain[*]}")${VIDEO_LABEL}"

# Audio
MAP_AUDIO=""
if ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$INPUT" | grep -q .; then
  # Build atempo chain
  build_atempo_chain() {
    local f="$1" chain=()
    f="$(LC_ALL=C awk -v x="$f" 'BEGIN{if (x<1.000001) x=1.0; printf("%.8f",x)}')"
    while LC_ALL=C awk -v x="$f" 'BEGIN{exit !(x>2.0000001)}'; do
      chain+=("atempo=2.0")
      f="$(LC_ALL=C awk -v x="$f" 'BEGIN{printf("%.8f", x/2.0)}')"
    done
    chain+=("atempo=$(LC_ALL=C awk -v x="$f" 'BEGIN{printf("%.8f",x)}')")
    (IFS=,; echo "${chain[*]}")
  }
  ATEMPO_CHAIN="$(build_atempo_chain "$SPEED")"
  FILTER_COMPLEX="${FILTER_COMPLEX};[0:a]${ATEMPO_CHAIN}${AUDIO_LABEL}"
  MAP_AUDIO="-map ${AUDIO_LABEL} -c:a aac -b:a 128k"
else
  MAP_AUDIO="-an"
fi

# Cap duration slightly under the limit
CAP="$(LC_ALL=C awk -v m="$MAXS" 'BEGIN{printf("%.3f",m-0.2)}')"

FFCMD=( ffmpeg -y -noautorotate -i "$INPUT"
  -filter_complex "$FILTER_COMPLEX"
  -map "${VIDEO_LABEL}" $MAP_AUDIO
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
