#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# commit_date_tools.sh
#
# Powerful Git commit-date tools:
#   1) amend-latest: set latest commit to a specific date/time
#   2) shift: shift ALL commits by hours/days
#   3) move: move ALL commits into day or night hours (randomized within window)
#
# Defaults:
#   - Timezone offset: +0200 (UTC+2)
#   - Day window:      09-18  (9am..6pm)
#   - Night window:    20-23,00-05  (8pm..11pm and midnight..5am)
#
# Requirements: git, GNU date (Linux 'date' or macOS 'gdate' from coreutils)
#
# Examples:
#   # 1) Set latest commit to specific day (random time) in UTC+2
#   ./commit_date_tools.sh amend-latest --date 25-12-2022
#
#   # 1b) Set latest commit to specific day & time with custom tz
#   ./commit_date_tools.sh amend-latest --date 25-12-2022 --time 14:30 --tz +0530
#
#   # 2) Shift entire history forward 7 hours
#   ./commit_date_tools.sh shift --hours 7
#
#   # 2b) Shift entire history back 2 days and 3 hours, timezone +0200
#   ./commit_date_tools.sh shift --days -2 --hours -3 --tz +0200
#
#   # 3) Move all commits into daytime (random hour in window)
#   ./commit_date_tools.sh move --to day
#
#   # 3b) Move to night hours with custom windows and timezone
#   ./commit_date_tools.sh move --to night --night-window 21-23,00-04 --tz -0500
#
# After rewriting history:
#   git push --force-with-lease
# -----------------------------------------------------------------------------

# ---------- Utilities ----------

# Pick GNU date (Linux: date, macOS: gdate)
DATE_BIN="$(command -v gdate || command -v date)"
if ! "$DATE_BIN" -d "@0" +%s >/dev/null 2>&1; then
  echo "Error: GNU 'date' required. On macOS: brew install coreutils (use gdate)." >&2
  exit 1
fi

require_git_repo() {
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "Not a git repo."; exit 1; }
}

# Parse "+HHMM" or "-HHMM" into seconds (supports half-hours like +0530)
tz_to_seconds() {
  local tz="$1" sign hh mm secs
  [[ "$tz" =~ ^[+-][0-9]{4}$ ]] || { echo "Invalid tz offset '$tz' (use +HHMM/-HHMM)"; exit 1; }
  sign="${tz:0:1}"
  hh=$((10#${tz:1:2}))
  mm=$((10#${tz:3:2}))
  secs=$((hh*3600 + mm*60))
  if [[ "$sign" == "-" ]]; then secs=$((-secs)); fi
  echo "$secs"
}

# Random int in [min,max] inclusive
rand_int() {
  local min=$1 max=$2
  echo $(( min + RANDOM % (max - min + 1) ))
}

# Build a space-separated list of allowed hours from a window spec like "09-18" or "20-23,00-05"
expand_windows_to_hours() {
  local spec="$1" part start end h hours=()
  IFS=',' read -ra PARTS <<< "$spec"
  for part in "${PARTS[@]}"; do
    [[ "$part" =~ ^([0-1][0-9]|2[0-3])\-([0-1][0-9]|2[0-3])$ ]] \
      || { echo "Invalid window '$part' (use HH-HH,HH-HH)"; exit 1; }
    start="${part%-*}"; end="${part#*-}"
    start=$((10#$start)); end=$((10#$end))
    if (( start <= end )); then
      for ((h=start; h<=end; h++)); do hours+=("$h"); done
    else
      # Wrap around midnight (e.g., 20-05)
      for ((h=start; h<=23; h++)); do hours+=("$h"); done
      for ((h=0; h<=end; h++));   do hours+=("$h"); done
    fi
  done
  echo "${hours[*]}"
}

# Turn Y-m-d H:M:S in the *local tz* into epoch seconds:
ymd_hms_to_epoch_in_tz() {
  local y="$1" m="$2" d="$3" H="$4" M="$5" S="$6" tz="$7"
  "$DATE_BIN" -d "${y}-${m}-${d} ${H}:${M}:${S} ${tz}" +%s
}

# ---------- Modes ----------

print_help() {
cat <<'EOF'
Usage:
  commit_date_tools.sh <mode> [options]

Modes:
  amend-latest      Set the latest commit to a specific date/time.
  shift             Shift ALL commits by hours/days.
  move              Move ALL commits into day or night hours (randomized).

Common options:
  --tz <+HHMM|-HHMM>   Timezone offset to use when writing dates (default +0200).

amend-latest options:
  --date DD-MM-YYYY    Required (e.g., 25-12-2024)
  --time HH:MM         Optional (random if omitted)

shift options:
  --hours N            Integer hours to shift (can be negative)
  --days N             Integer days to shift   (can be negative)

move options:
  --to day|night       Required
  --day-window  HH-HH          Default 09-18
  --night-window HH-HH,HH-HH   Default 20-23,00-05

Notes:
  • This rewrites history (all branches & tags). Backup first.
  • After running: git push --force-with-lease
EOF
}

# ---------- Argument parsing ----------

MODE="${1:-}"
[[ -z "${MODE}" ]] && { print_help; exit 1; }
shift || true

TZ_OFFSET="+0200"
DATE_DDMMYYYY=""
TIME_HHMM=""
SHIFT_HOURS="0"
SHIFT_DAYS="0"
MOVE_TO=""
DAY_WINDOW="09-18"
NIGHT_WINDOW="20-23,00-05"

while (( "$#" )); do
  case "$1" in
    --tz)            TZ_OFFSET="${2:?}"; shift 2;;
    --date)          DATE_DDMMYYYY="${2:?}"; shift 2;;
    --time)          TIME_HHMM="${2:?}"; shift 2;;
    --hours)         SHIFT_HOURS="${2:?}"; shift 2;;
    --days)          SHIFT_DAYS="${2:?}"; shift 2;;
    --to)            MOVE_TO="${2:?}"; shift 2;;
    --day-window)    DAY_WINDOW="${2:?}"; shift 2;;
    --night-window)  NIGHT_WINDOW="${2:?}"; shift 2;;
    -h|--help)       print_help; exit 0;;
    *) echo "Unknown option: $1"; echo; print_help; exit 1;;
  esac
done

# ---------- Validations ----------

require_git_repo
TZ_SECS="$(tz_to_seconds "$TZ_OFFSET")"

# ---------- Implementations ----------

amend_latest() {
  [[ "$DATE_DDMMYYYY" =~ ^([0-2][0-9]|3[0-1])-([0][1-9]|1[0-2])-[0-9]{4}$ ]] \
    || { echo "Invalid --date. Use DD-MM-YYYY"; exit 1; }
  IFS='-' read -r DD MM YYYY <<< "$DATE_DDMMYYYY"

  if [[ -z "$TIME_HHMM" ]]; then
    HH=$(rand_int 0 23)
    MMm=$(rand_int 0 59)
    printf -v TIME_HHMM "%02d:%02d" "$HH" "$MMm"
  else
    [[ "$TIME_HHMM" =~ ^([0-1][0-9]|2[0-3]):([0-5][0-9])$ ]] \
      || { echo "Invalid --time. Use HH:MM"; exit 1; }
  fi

  HH="${TIME_HHMM%:*}"
  MI="${TIME_HHMM#*:}"
  SS="00"

  EPOCH="$("$DATE_BIN" -d "${YYYY}-${MM}-${DD} ${HH}:${MI}:${SS} ${TZ_OFFSET}" +%s)"

  GIT_AUTHOR_DATE="${EPOCH} ${TZ_OFFSET}" \
  GIT_COMMITTER_DATE="${EPOCH} ${TZ_OFFSET}" \
    git commit --amend --no-edit

  echo "✓ Amended latest commit date to ${YYYY}-${MM}-${DD} ${HH}:${MI}:${SS} ${TZ_OFFSET}"
}

shift_history() {
  local shift_secs=$(( SHIFT_DAYS*86400 + SHIFT_HOURS*3600 ))
  echo "Shifting ALL commits by ${SHIFT_DAYS} day(s) and ${SHIFT_HOURS} hour(s) [${shift_secs}s]; tz=${TZ_OFFSET}"
  if [[ "$shift_secs" -eq 0 ]]; then
    echo "Nothing to do (shift is zero)."; exit 0
  fi

  git filter-branch -f --tag-name-filter cat --env-filter "
    shift_secs=${shift_secs}
    tz='${TZ_OFFSET}'
    to_epoch() { $DATE_BIN -d \"\$1\" +%s; }

    a_ep=\$(to_epoch \"\$GIT_AUTHOR_DATE\");     c_ep=\$(to_epoch \"\$GIT_COMMITTER_DATE\")
    a_new=\$((a_ep + shift_secs));               c_new=\$((c_ep + shift_secs))
    export GIT_AUTHOR_DATE=\"\$a_new \$tz\"
    export GIT_COMMITTER_DATE=\"\$c_new \$tz\"
  " -- --branches --tags >/dev/null
  echo "✓ Done. Remember to: git push --force-with-lease"
}

parse_windows_to_intervals() {
  local spec="$1"
  WIN_STARTS=()
  WIN_ENDS=()
  IFS=',' read -ra PARTS <<< "$spec"
  for part in "${PARTS[@]}"; do
    [[ "$part" =~ ^([0-1][0-9]|2[0-3])\-([0-1][0-9]|2[0-3])$ ]] \
      || { echo "Invalid window segment '$part' (use HH-HH)"; exit 1; }
    local s="${BASH_REMATCH[1]}" e="${BASH_REMATCH[2]}"
    local ssec=$((10#$s * 3600))
    local esec=$(( (10#$e + 1) * 3600 )) # end is exclusive
    if (( esec > 86400 )); then esec=86400; fi
    if (( 10#$s <= 10#$e )); then
      WIN_STARTS+=("$ssec"); WIN_ENDS+=("$esec")
    else
      # wrap across midnight, split into two intervals
      WIN_STARTS+=("$ssec"); WIN_ENDS+=("86400")
      WIN_STARTS+=("0");    WIN_ENDS+=("$esec")
    fi
  done
  # sort by start (tiny N, simple insertion sort)
  local i j keyS keyE
  for ((i=1; i<${#WIN_STARTS[@]}; i++)); do
    keyS=${WIN_STARTS[i]}; keyE=${WIN_ENDS[i]}; j=$((i-1))
    while (( j>=0 && WIN_STARTS[j] > keyS )); do
      WIN_STARTS[j+1]=${WIN_STARTS[j]}; WIN_ENDS[j+1]=${WIN_ENDS[j]}; j=$((j-1))
    done
    WIN_STARTS[j+1]=$keyS; WIN_ENDS[j+1]=$keyE
  done
  # merge overlaps / adjacents
  local mergedS=() mergedE=()
  for ((i=0;i<${#WIN_STARTS[@]};i++)); do
    if (( ${#mergedS[@]}==0 )); then
      mergedS+=("${WIN_STARTS[i]}"); mergedE+=("${WIN_ENDS[i]}")
    else
      local last=$(( ${#mergedS[@]} - 1 ))
      if (( WIN_STARTS[i] <= mergedE[last] )); then
        # extend
        if (( WIN_ENDS[i] > mergedE[last] )); then mergedE[last]=${WIN_ENDS[i]}; fi
      else
        mergedS+=("${WIN_STARTS[i]}"); mergedE+=("${WIN_ENDS[i]}")
      fi
    fi
  done
  WIN_STARTS=("${mergedS[@]}"); WIN_ENDS=("${mergedE[@]}")
  # total allowed seconds
  ALLOWED_LEN=0
  for ((i=0;i<${#WIN_STARTS[@]};i++)); do
    ALLOWED_LEN=$((ALLOWED_LEN + WIN_ENDS[i] - WIN_STARTS[i]))
  done
  (( ALLOWED_LEN > 0 )) || { echo "Window has zero length"; exit 1; }
}

# Map a position p in [0, ALLOWED_LEN-1] to absolute seconds since local midnight
# inside the union of intervals.
union_pos_to_seconds() {
  local p=$1
  for ((i=0;i<${#WIN_STARTS[@]};i++)); do
    local seglen=$(( WIN_ENDS[i] - WIN_STARTS[i] ))
    if (( p < seglen )); then
      echo $(( WIN_STARTS[i] + p ))
      return
    fi
    p=$(( p - seglen ))
  done
  echo $(( WIN_ENDS[${#WIN_ENDS[@]}-1] - 1 ))
}

# --- move_history(): preserves per-day order & keeps same local day ---
move_history() {
  local target="$1"
  local window_spec
  if [[ "$target" == "day" ]]; then
    window_spec="$DAY_WINDOW"
    echo "Moving ALL commits into DAY hours [$DAY_WINDOW] in tz=${TZ_OFFSET}"
  else
    window_spec="$NIGHT_WINDOW"
    echo "Moving ALL commits into NIGHT hours [$NIGHT_WINDOW] in tz=${TZ_OFFSET}"
  fi

  parse_windows_to_intervals "$window_spec"

  # 1) First pass: count commits per local day (by committer date)
  declare -A DAY_COUNT=()
  local tz_secs
  tz_secs="$(tz_to_seconds "$TZ_OFFSET")"

  while IFS=' ' read -r sha ct; do
    [[ -n "$sha" ]] || continue
    # local day key in target tz
    local local_ep=$(( ct + tz_secs ))
    local day
    day="$($DATE_BIN -u -d "@$local_ep" +%Y-%m-%d)"
    DAY_COUNT["$day"]=$(( ${DAY_COUNT["$day"]:-0} + 1 ))
  done < <(git log --all --reverse --pretty=format:'%H %ct')

  # 2) Second pass: assign evenly spaced times inside window per day, preserving order
  local STATE
  STATE="$(mktemp -d)"
  trap 'rm -rf "$STATE"' EXIT
  mkdir -p "$STATE/map"

  declare -A DAY_INDEX=()
  while IFS=' ' read -r sha ct; do
    [[ -n "$sha" ]] || continue
    local local_ep=$(( ct + tz_secs ))
    local day
    day="$($DATE_BIN -u -d "@$local_ep" +%Y-%m-%d)"
    local idx=${DAY_INDEX["$day"]:-0}
    local n=${DAY_COUNT["$day"]}

    # Even spacing strictly preserves order; places commits inside the window.
    # pos = floor( (idx+1) * (ALLOWED_LEN-1) / (n+1) )
    local pos=$(( ((idx + 1) * (ALLOWED_LEN - 1)) / (n + 1) ))
    (( pos < 0 )) && pos=0
    (( pos >= ALLOWED_LEN )) && pos=$((ALLOWED_LEN - 1))

    local sec_in_day
    sec_in_day="$(union_pos_to_seconds "$pos")"

    # Build final epoch: interpret as local time in TZ_OFFSET, then convert to UTC epoch
    local new_epoch
    new_epoch="$($DATE_BIN -d "${day} 00:00:00 ${TZ_OFFSET}" +%s)"
    new_epoch=$(( new_epoch + sec_in_day ))

    printf '%s' "$new_epoch" > "$STATE/map/$sha"
    DAY_INDEX["$day"]=$(( idx + 1 ))
  done < <(git log --all --reverse --pretty=format:'%H %ct')

  # 3) Apply mapping in one pass
  MAPPING_DIR="$STATE/map" TZ_OFFSET_APPLY="$TZ_OFFSET" \
  git filter-branch -f --tag-name-filter cat --env-filter '
    if [ -f "$MAPPING_DIR/$GIT_COMMIT" ]; then
      new_epoch=$(cat "$MAPPING_DIR/$GIT_COMMIT")
      export GIT_AUTHOR_DATE="$new_epoch $TZ_OFFSET_APPLY"
      export GIT_COMMITTER_DATE="$new_epoch $TZ_OFFSET_APPLY"
    fi
  ' -- --branches --tags >/dev/null

  echo "✓ Done. Per-day order preserved; commits stay on the same local day."
  echo "   Next: git push --force-with-lease"
}

# ---------- Dispatch ----------

case "$MODE" in
  amend-latest)
    [[ -n "$DATE_DDMMYYYY" ]] || { echo "amend-latest requires --date DD-MM-YYYY"; exit 1; }
    amend_latest
    ;;
  shift)
    shift_history
    ;;
  move)
    [[ "$MOVE_TO" =~ ^(day|night)$ ]] || { echo "move requires --to day|night"; exit 1; }
    move_history "$MOVE_TO"
    ;;
  *)
    echo "Unknown mode: $MODE"
    print_help
    exit 1
    ;;
esac
