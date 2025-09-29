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

move_history() {
  local target="$1"

  local hours_list=""
  if [[ "$target" == "day" ]]; then
    hours_list="$(expand_windows_to_hours "$DAY_WINDOW")"
    echo "Moving ALL commits into DAY hours [${DAY_WINDOW}] in tz=${TZ_OFFSET}"
  else
    hours_list="$(expand_windows_to_hours "$NIGHT_WINDOW")"
    echo "Moving ALL commits into NIGHT hours [${NIGHT_WINDOW}] in tz=${TZ_OFFSET}"
  fi

  # Pack the hours list into a bash array initializer string
  local hours_csv="${hours_list// /,}"

  git filter-branch -f --tag-name-filter cat --env-filter "
    tz='${TZ_OFFSET}'
    tz_secs=$(tz_to_seconds "${TZ_OFFSET}")
  " -- --branches --tags >/dev/null 2>&1 && true

  # We need the tz_to_seconds helper inside the filter; inject it plus logic:
  git filter-branch -f --tag-name-filter cat --env-filter "
    tz='${TZ_OFFSET}'
    tz_to_seconds() {
      local tz=\"\$1\" sign hh mm secs
      [[ \"\$tz\" =~ ^[+-][0-9]{4}\$ ]] || { echo 'bad tz' >&2; exit 1; }
      sign=\"\${tz:0:1}\"; hh=\$((10#\${tz:1:2})); mm=\$((10#\${tz:3:2}))
      secs=\$((hh*3600 + mm*60)); [[ \"\$sign\" == '-' ]] && secs=\$((-secs))
      echo \"\$secs\"
    }

    tz_secs=\$(tz_to_seconds \"\$tz\")
    to_epoch() { $DATE_BIN -d \"\$1\" +%s; }
    from_local_YmdHMS_to_epoch() { # args: Y M D H M S, interpret as LOCAL (tz offset), return UTC epoch
      local Y=\"\$1\" Mo=\"\$2\" D=\"\$3\" H=\"\$4\" Mi=\"\$5\" S=\"\$6\"
      $DATE_BIN -d \"\${Y}-\${Mo}-\${D} \${H}:\${Mi}:\${S} UTC\" +%s
    }

    # Pick a random allowed hour (uniform)
    pick_hour() {
      local IFS=','; local raw='${hours_csv}'
      read -ra H <<< \"\$raw\"
      local count=\${#H[@]}
      local idx=\$((RANDOM % count))
      echo \${H[\$idx]}
    }

    # For each commit:
    a_ep=\$(to_epoch \"\$GIT_AUTHOR_DATE\")
    c_ep=\$(to_epoch \"\$GIT_COMMITTER_DATE\")

    # Convert to 'local' by applying tz offset (so windows are in given tz)
    a_local=\$((a_ep + tz_secs))
    c_local=\$((c_ep + tz_secs))

    # Extract local Y-m-d; choose random HH:MM:SS in allowed window
    Y=\$($DATE_BIN -u -d @\$a_local +%Y)
    Mo=\$($DATE_BIN -u -d @\$a_local +%m)
    D=\$($DATE_BIN -u -d @\$a_local +%d)

    H=\$(pick_hour)
    Mi=\$((RANDOM % 60))
    S=\$((RANDOM % 60))

    new_local_epoch=\$($DATE_BIN -u -d \"\${Y}-\${Mo}-\${D} \${H}:\${Mi}:\${S}\" +%s)
    a_new=\$((new_local_epoch - tz_secs))

    # Mirror author -> committer with same new time on that commit's day
    Yc=\$($DATE_BIN -u -d @\$c_local +%Y)
    Moc=\$($DATE_BIN -u -d @\$c_local +%m)
    Dc=\$($DATE_BIN -u -d @\$c_local +%d)
    new_local_epoch_c=\$($DATE_BIN -u -d \"\${Yc}-\${Moc}-\${Dc} \${H}:\${Mi}:\${S}\" +%s)
    c_new=\$((new_local_epoch_c - tz_secs))

    export GIT_AUTHOR_DATE=\"\$a_new \$tz\"
    export GIT_COMMITTER_DATE=\"\$c_new \$tz\"
  " -- --branches --tags >/dev/null

  echo "✓ Done. Remember to: git push --force-with-lease"
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
