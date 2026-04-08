#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="${0##*/}"
MODE=""
QUIET=0

FF_DIR="$HOME/.mozilla/firefox"
PROFILES_INI=""
USB_MOUNT=""
BACKUP_DIR=""

declare -a PROFILE_NAMES=()
declare -a PROFILE_PATHS_RAW=()
declare -a PROFILE_IS_REL=()
declare -a PROFILE_DEFAULTS=()
declare -a PROFILE_RESOLVED=()

on_error() {
  local exit_code=$?
  printf '[%s] ERROR: Script failed near line %s (exit %s)\n' \
    "$(date +%H:%M:%S)" "${BASH_LINENO[0]:-unknown}" "$exit_code" >&2
  exit "$exit_code"
}
trap on_error ERR

usage() {
  cat <<EOF
Usage:
  $SCRIPT_NAME backup [--usb PATH] [--quiet]
  $SCRIPT_NAME restore [--usb PATH] [--backup-dir PATH] [--quiet]
  $SCRIPT_NAME --help
EOF
}

log() {
  if [[ "$QUIET" -eq 0 ]]; then
    printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2
  fi
}

warn() {
  printf '[%s] WARNING: %s\n' "$(date +%H:%M:%S)" "$*" >&2
}

die() {
  printf '[%s] ERROR: %s\n' "$(date +%H:%M:%S)" "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

require_tools() {
  local cmd
  for cmd in \
    awk grep sed cp mv rsync lsblk findmnt mkdir date basename dirname \
    find sort head readlink pgrep mountpoint sync python3 sqlite3 rm mktemp
  do
    require_cmd "$cmd"
  done
}

firefox_must_be_closed() {
  log "Checking whether Firefox is fully closed..."
  if pgrep -x firefox >/dev/null 2>&1 \
     || pgrep -x firefox-bin >/dev/null 2>&1 \
     || pgrep -x MainThread >/dev/null 2>&1; then
    die "Firefox appears to be running. Close it completely and run again."
  fi
  log "Firefox is closed."
}

detect_firefox_dir() {
  local snap_profile="$HOME/snap/firefox/common/.mozilla/firefox"
  local flatpak_profile="$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
  local ff_cmd ff_real

  if [[ -d "$snap_profile" ]]; then
    FF_DIR="$snap_profile"
  elif [[ -d "$flatpak_profile" ]]; then
    FF_DIR="$flatpak_profile"
  else
    ff_cmd="$(command -v firefox 2>/dev/null || true)"
    if [[ -n "$ff_cmd" ]]; then
      ff_real="$(readlink -f "$ff_cmd" 2>/dev/null || true)"
      if [[ "$ff_real" == */snap/firefox/* ]] || grep -qF "/snap/firefox/" "$ff_cmd" 2>/dev/null; then
        FF_DIR="$snap_profile"
      elif grep -qF "org.mozilla.firefox" "$ff_cmd" 2>/dev/null; then
        FF_DIR="$flatpak_profile"
      fi
    fi
  fi

  PROFILES_INI="$FF_DIR/profiles.ini"
  log "Firefox profile directory: $FF_DIR"
}

_verify_mount_path() {
  local path="$1" probe

  [[ -d "$path" ]] || die "Path does not exist: $path"

  if ! findmnt -M "$path" >/dev/null 2>&1 && ! mountpoint -q "$path" 2>/dev/null; then
    warn "Path exists but does not look like a mount point: $path"
  fi

  probe="$path/.firefox-usb-probe.$$"
  touch "$probe" 2>/dev/null || die "USB path is not writable: $path"
  rm -f "$probe"
}

_usb_collect_mounts() {
  lsblk -P -o NAME,TRAN,RM,MOUNTPOINT,LABEL,SIZE,FSTYPE 2>/dev/null | awk '
    function uq(s) { gsub(/^"/, "", s); gsub(/"$/, "", s); return s }
    {
      name=tran=rm=mp=label=size=fs=""
      for (i=1; i<=NF; i++) {
        split($i, kv, "=")
        key=kv[1]
        val=uq(kv[2])
        if (key=="NAME") name=val
        else if (key=="TRAN") tran=val
        else if (key=="RM") rm=val
        else if (key=="MOUNTPOINT") mp=val
        else if (key=="LABEL") label=val
        else if (key=="SIZE") size=val
        else if (key=="FSTYPE") fs=val
      }
      if (mp != "" && (tran=="usb" || rm=="1")) {
        if (name ~ /^(sr|loop|zram)/) next
        printf "%s\t/dev/%s\t%s\t%s\t%s\n", mp, name, \
               (label==""?"-":label), (size==""?"?":size), (fs==""?"?":fs)
      }
    }
  ' | awk -F'\t' 'NF && !seen[$1]++' | sort
}

pick_usb_mount() {
  local raw_mounts=""
  local -a mount_paths=() devices=() labels=() sizes=() fstypes=()
  local mp dev lbl sz fs count choice i

  if [[ -n "${USB_MOUNT:-}" ]]; then
    log "Using USB path from command line: $USB_MOUNT"
    _verify_mount_path "$USB_MOUNT"
    return 0
  fi

  raw_mounts="$(_usb_collect_mounts)"
  [[ -n "$raw_mounts" ]] || die "No mounted USB drives found."

  while IFS=$'\t' read -r mp dev lbl sz fs; do
    [[ -n "$mp" ]] || continue
    mount_paths+=("$mp")
    devices+=("$dev")
    labels+=("$lbl")
    sizes+=("$sz")
    fstypes+=("$fs")
  done <<< "$raw_mounts"

  count="${#mount_paths[@]}"
  (( count > 0 )) || die "USB detection returned no usable mount points."

  if (( count == 1 )); then
    USB_MOUNT="${mount_paths[0]}"
    log "One USB drive found. Auto-selecting: $USB_MOUNT"
    _verify_mount_path "$USB_MOUNT"
    return 0
  fi

  echo
  echo "Mounted USB drives:"
  echo
  printf '  %-4s %-30s %-12s %-14s %-8s %s\n' "#" "MOUNTPOINT" "DEVICE" "LABEL" "SIZE" "FS"
  for (( i=0; i<count; i++ )); do
    printf '  [%-2d] %-30s %-12s %-14s %-8s %s\n' \
      "$((i + 1))" "${mount_paths[$i]}" "${devices[$i]}" "${labels[$i]}" "${sizes[$i]}" "${fstypes[$i]}"
  done
  echo

  read -rp "Select USB drive [1-$count]: " choice
  [[ "$choice" =~ ^[0-9]+$ ]] || die "Selection must be a number."
  (( choice >= 1 && choice <= count )) || die "Invalid selection: $choice"

  USB_MOUNT="${mount_paths[$((choice - 1))]}"
  log "Selected USB mount: $USB_MOUNT"
  _verify_mount_path "$USB_MOUNT"
}

discover_profiles() {
  local name rel path def resolved
  local found_any=0

  PROFILE_NAMES=()
  PROFILE_PATHS_RAW=()
  PROFILE_IS_REL=()
  PROFILE_DEFAULTS=()
  PROFILE_RESOLVED=()

  if [[ -f "$PROFILES_INI" ]]; then
    while IFS=$'\t' read -r name def rel path; do
      [[ -n "$path" ]] || continue

      if [[ "$rel" == "1" ]]; then
        resolved="$FF_DIR/$path"
      else
        resolved="$path"
      fi

      [[ -d "$resolved" ]] || continue

      PROFILE_NAMES+=("${name:-unnamed}")
      PROFILE_PATHS_RAW+=("$path")
      PROFILE_IS_REL+=("$rel")
      PROFILE_DEFAULTS+=("$def")
      PROFILE_RESOLVED+=("$resolved")
      found_any=1
    done < <(
      awk '
        BEGIN { in_profile=0; name=""; path=""; rel="1"; def="0" }
        function flush() {
          if (in_profile && path != "")
            printf "%s\t%s\t%s\t%s\n", name, def, rel, path
        }
        /^\[Profile[0-9]+\]$/ { flush(); in_profile=1; name=""; path=""; rel="1"; def="0"; next }
        /^\[/                 { flush(); in_profile=0; next }
        in_profile && /^Name=/       { sub(/^Name=/, "", $0); name=$0; next }
        in_profile && /^Path=/       { sub(/^Path=/, "", $0); path=$0; next }
        in_profile && /^IsRelative=/ { sub(/^IsRelative=/, "", $0); rel=$0; next }
        in_profile && /^Default=1$/  { def="1"; next }
        END { flush() }
      ' "$PROFILES_INI"
    )
  fi

  if [[ "$found_any" -eq 0 ]]; then
    warn "profiles.ini not found or did not list usable profiles; falling back to FF_DIR/Profiles/* discovery."
    if [[ -d "$FF_DIR/Profiles" ]]; then
      while IFS= read -r d; do
        [[ -d "$d" ]] || continue
        PROFILE_NAMES+=("$(basename "$d")")
        PROFILE_PATHS_RAW+=("Profiles/$(basename "$d")")
        PROFILE_IS_REL+=("1")
        PROFILE_DEFAULTS+=("0")
        PROFILE_RESOLVED+=("$d")
        found_any=1
      done < <(find "$FF_DIR/Profiles" -mindepth 1 -maxdepth 1 -type d | sort)
    fi
  fi

  [[ "$found_any" -eq 1 ]] || die "Could not find any Firefox profiles."

  log "Discovered ${#PROFILE_RESOLVED[@]} Firefox profile(s)."
}

json_login_count() {
  local json_file="$1"
  python3 - "$json_file" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)
logins = data.get("logins", [])
if not isinstance(logins, list):
    raise SystemExit(2)
print(len(logins))
PY
}

validate_json_file() {
  local json_file="$1"
  python3 - "$json_file" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    json.load(f)
print("OK")
PY
}

sqlite_quick_check() {
  local db="$1"
  local out
  out="$(sqlite3 -readonly "$db" 'PRAGMA quick_check;' 2>/dev/null | tail -n 1 || true)"
  [[ "$out" == "ok" ]] || die "SQLite quick_check failed for: $db (result: ${out:-empty})"
}

sqlite_integrity_check() {
  local db="$1"
  local out
  out="$(sqlite3 -readonly "$db" 'PRAGMA integrity_check;' 2>/dev/null | tail -n 1 || true)"
  [[ "$out" == "ok" ]] || die "SQLite integrity_check failed for: $db (result: ${out:-empty})"
}

validate_profile_integrity() {
  local profile_dir="$1"
  local profile_name="$2"
  local db count
  local has_logins=0
  local has_key4=0

  [[ -d "$profile_dir" ]] || die "Profile directory not found: $profile_dir"

  if [[ -f "$profile_dir/logins.json" ]]; then
    has_logins=1
    [[ -s "$profile_dir/logins.json" ]] || die "logins.json exists but is empty in profile: $profile_name ($profile_dir)"
    validate_json_file "$profile_dir/logins.json" >/dev/null
  fi

  if [[ -f "$profile_dir/key4.db" ]]; then
    has_key4=1
    [[ -s "$profile_dir/key4.db" ]] || die "key4.db exists but is empty in profile: $profile_name ($profile_dir)"
    sqlite_integrity_check "$profile_dir/key4.db"
  fi

  if (( has_logins != has_key4 )); then
    die "Profile '$profile_name' has only one of logins.json/key4.db. Both must be present together."
  fi

  if (( has_logins == 1 )); then
    count="$(json_login_count "$profile_dir/logins.json")"
    log "Profile '$profile_name': password store present, logins count = $count"
  else
    log "Profile '$profile_name': no saved-password store detected"
  fi

  while IFS= read -r db; do
    [[ -n "$db" ]] || continue
    sqlite_quick_check "$db"
  done < <(
    find "$profile_dir" -maxdepth 1 -type f \
      \( -name '*.sqlite' -o -name '*.db' \) \
      ! -name 'lock' \
      ! -name '*.sqlite-wal' \
      ! -name '*.sqlite-shm' \
      | sort
  )

  log "Profile '$profile_name': SQLite checks passed."
}

clean_restored_profile() {
  local profile_dir="$1"
  local stale

  [[ -d "$profile_dir" ]] || return 0

  while IFS= read -r -d '' stale; do
    rm -f -- "$stale"
  done < <(
    find "$profile_dir" \
      \( -name 'lock' -o -name '.parentlock' -o -name '*.sqlite-wal' -o -name '*.sqlite-shm' \) \
      -type f -print0
  )

  rm -f -- "$profile_dir/compatibility.ini"
}

backup_mode() {
  local ts dest_root profiles_dir metadata_file i default_seen=0
  local dest_profile_dir name path rel def resolved

  log "Starting Firefox backup..."
  detect_firefox_dir
  firefox_must_be_closed
  pick_usb_mount
  discover_profiles

  ts="$(date +%Y%m%d-%H%M%S)"
  dest_root="$USB_MOUNT/firefox-profile-backup-$ts"
  profiles_dir="$dest_root/profiles"
  metadata_file="$dest_root/profiles.tsv"

  mkdir -p "$profiles_dir"

  {
    printf 'IDX\tNAME\tDEFAULT\tSRC_IS_REL\tSRC_PATH\tBACKUP_DIR\n'
  } > "$metadata_file"

  for (( i=0; i<${#PROFILE_RESOLVED[@]}; i++ )); do
    name="${PROFILE_NAMES[$i]}"
    path="${PROFILE_PATHS_RAW[$i]}"
    rel="${PROFILE_IS_REL[$i]}"
    def="${PROFILE_DEFAULTS[$i]}"
    resolved="${PROFILE_RESOLVED[$i]}"

    [[ -d "$resolved" ]] || die "Profile disappeared during backup: $resolved"

    validate_profile_integrity "$resolved" "$name"

    dest_profile_dir="$profiles_dir/$(basename "$resolved")"
    if [[ -e "$dest_profile_dir" ]]; then
      dest_profile_dir="$profiles_dir/$(basename "$resolved").$i"
    fi

    log "Backing up profile '$name' from $resolved"
    mkdir -p "$dest_profile_dir"

    rsync -aH --delete \
      --exclude='lock' \
      --exclude='.parentlock' \
      --exclude='*.sqlite-wal' \
      --exclude='*.sqlite-shm' \
      --exclude='cache2/' \
      --exclude='startupCache/' \
      --exclude='crashes/' \
      --exclude='minidumps/' \
      "$resolved/" "$dest_profile_dir/"

    validate_profile_integrity "$dest_profile_dir" "$name"

    if [[ "$def" == "1" ]]; then
      default_seen=1
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$i" "$name" "$def" "$rel" "$path" "$(basename "$dest_profile_dir")" >> "$metadata_file"
  done

  cat > "$dest_root/RESTORE-INFO.txt" <<EOF
Firefox profile backup
Created: $ts
Original Firefox dir: $FF_DIR
Profiles backed up: ${#PROFILE_RESOLVED[@]}
Original profiles.ini present: $( [[ -f "$PROFILES_INI" ]] && echo yes || echo no )
Strategy: restore all profile directories and regenerate a clean profiles.ini
EOF

  sync

  log "Backup complete."
  echo
  echo "Saved to:"
  echo "  $dest_root"
}

unique_profile_basename() {
  local base="$1"
  local candidate="$base"
  local n=1

  while [[ -e "$FF_DIR/Profiles/$candidate" ]]; do
    candidate="${base}.restored$n"
    n=$((n + 1))
  done

  printf '%s\n' "$candidate"
}

write_profiles_ini_from_metadata() {
  local metadata_file="$1"
  local output_file="$2"
  local idx=0
  local line name default backup_dir basename rel_path write_default=0
  local -a lines=()

  {
    echo "[General]"
    echo "StartWithLastProfile=1"
    echo "Version=2"
    echo
  } > "$output_file"

  while IFS=$'\t' read -r _idx name default _src_is_rel _src_path backup_dir restored_basename; do
    [[ "$_idx" == "IDX" ]] && continue
    rel_path="Profiles/$restored_basename"

    {
      echo "[Profile$idx]"
      echo "Name=$name"
      echo "IsRelative=1"
      echo "Path=$rel_path"
      if [[ "$default" == "1" && "$write_default" -eq 0 ]]; then
        echo "Default=1"
        write_default=1
      fi
      echo
    } >> "$output_file"

    idx=$((idx + 1))
  done < "$metadata_file"

  if [[ "$write_default" -eq 0 ]]; then
    awk '
      BEGIN { done=0 }
      { print }
      /^\[Profile0\]$/ { in0=1; next }
      in0 && /^Name=/ && done==0 { print "Default=1"; done=1; in0=0 }
    ' "$output_file" > "$output_file.tmp"
    mv "$output_file.tmp" "$output_file"
  fi
}

restore_mode() {
  local profiles_dir metadata_file line
  local src_profile_dir dest_basename dest_profile_dir safety_dir
  local idx name default src_is_rel src_path backup_dir ts temp_metadata
  local restored_basename

  log "Starting Firefox restore..."
  detect_firefox_dir
  firefox_must_be_closed

  if [[ -z "$BACKUP_DIR" ]]; then
    pick_usb_mount
    BACKUP_DIR="$(find "$USB_MOUNT" -maxdepth 1 -type d -name 'firefox-profile-backup-*' | sort | tail -n 1)"
    [[ -n "$BACKUP_DIR" ]] || die "No firefox-profile-backup-* folders found in: $USB_MOUNT"
    log "Using latest backup: $BACKUP_DIR"
  else
    [[ -d "$BACKUP_DIR" ]] || die "Backup directory not found: $BACKUP_DIR"
    log "Using backup directory from command line: $BACKUP_DIR"
  fi

  profiles_dir="$BACKUP_DIR/profiles"
  metadata_file="$BACKUP_DIR/profiles.tsv"

  [[ -d "$profiles_dir" ]] || die "Backup profiles directory not found: $profiles_dir"
  [[ -f "$metadata_file" ]] || die "Backup metadata not found: $metadata_file"

  mkdir -p "$FF_DIR/Profiles"

  ts="$(date +%Y%m%d-%H%M%S)"
  temp_metadata="$(mktemp)"

  {
    printf 'IDX\tNAME\tDEFAULT\tSRC_IS_REL\tSRC_PATH\tBACKUP_DIR\tRESTORED_BASENAME\n'
  } > "$temp_metadata"

  while IFS=$'\t' read -r idx name default src_is_rel src_path backup_dir; do
    [[ "$idx" == "IDX" ]] && continue

    src_profile_dir="$profiles_dir/$backup_dir"
    [[ -d "$src_profile_dir" ]] || die "Missing backed-up profile directory: $src_profile_dir"

    validate_profile_integrity "$src_profile_dir" "$name"

    dest_basename="$(unique_profile_basename "$backup_dir")"
    dest_profile_dir="$FF_DIR/Profiles/$dest_basename"

    if [[ -e "$dest_profile_dir" ]]; then
      safety_dir="$dest_profile_dir.pre-restore-$ts"
      warn "Target profile already exists, moving aside: $dest_profile_dir -> $safety_dir"
      mv "$dest_profile_dir" "$safety_dir"
    fi

    mkdir -p "$dest_profile_dir"

    log "Restoring profile '$name' to $dest_profile_dir"
    rsync -aH --delete "$src_profile_dir/" "$dest_profile_dir/"

    clean_restored_profile "$dest_profile_dir"
    validate_profile_integrity "$dest_profile_dir" "$name"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$idx" "$name" "$default" "$src_is_rel" "$src_path" "$backup_dir" "$dest_basename" >> "$temp_metadata"
  done < "$metadata_file"

  if [[ -f "$FF_DIR/installs.ini" ]]; then
    warn "Removing stale installs.ini so Firefox can regenerate install mappings."
    rm -f -- "$FF_DIR/installs.ini"
  fi

  if [[ -f "$PROFILES_INI" ]]; then
    safety_dir="$FF_DIR/profiles.ini.pre-restore-$ts"
    log "Saving existing profiles.ini to: $safety_dir"
    cp -a "$PROFILES_INI" "$safety_dir"
  fi

  write_profiles_ini_from_metadata "$temp_metadata" "$PROFILES_INI"
  rm -f -- "$temp_metadata"

  sync

  log "Restore complete."
  echo
  echo "Restored all profiles into:"
  echo "  $FF_DIR/Profiles"
  echo
  echo "Start Firefox normally."
  echo "If Firefox opens a new empty profile anyway, run:"
  echo "  firefox -P"
  echo "and select one of the restored profiles."
}

parse_args() {
  while (($#)); do
    case "$1" in
      backup|restore)
        [[ -z "$MODE" ]] || die "Only one mode may be specified."
        MODE="$1"
        shift
        ;;
      --usb)
        shift
        [[ $# -gt 0 ]] || die "--usb requires a path"
        USB_MOUNT="$1"
        shift
        ;;
      --backup-dir)
        shift
        [[ $# -gt 0 ]] || die "--backup-dir requires a path"
        BACKUP_DIR="$1"
        shift
        ;;
      -q|--quiet)
        QUIET=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done

  [[ -n "$MODE" ]] || { usage; exit 1; }
}

main() {
  parse_args "$@"
  require_tools

  case "$MODE" in
    backup)  backup_mode ;;
    restore) restore_mode ;;
    *) die "Unsupported mode: $MODE" ;;
  esac
}

main "$@"
