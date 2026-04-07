#!/usr/bin/env bash
set -Euo pipefail

SCRIPT_NAME="${0##*/}"
MODE=""
QUIET=0

FF_DIR="$HOME/.mozilla/firefox"
PROFILES_INI="$FF_DIR/profiles.ini"
USB_MOUNT=""
BACKUP_DIR=""

DEFAULT_PROFILE_SPEC=""
IS_RELATIVE=""
PROFILE_PATH_RAW=""
PROFILE_DIR=""
PROFILE_BASENAME=""

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
  log "Checking required tools..."
  for cmd in awk grep sed cp mv rsync lsblk findmnt mkdir date basename dirname find sort tail head readlink pgrep mountpoint; do
    require_cmd "$cmd"
  done
  log "Required tools look good."
}

firefox_must_be_closed() {
  log "Checking whether Firefox is closed..."
  if pgrep -x firefox >/dev/null 2>&1; then
    die "Firefox is running. Close it completely and run again."
  fi
  log "Firefox is closed."
}

detect_firefox_dir() {
  # Detection order:
  #   1. Existing Snap profile directory   (~/.../snap/firefox/common/.mozilla/firefox)
  #   2. Existing Flatpak profile directory (~/.var/app/org.mozilla.firefox/.mozilla/firefox)
  #   3. Firefox binary/wrapper inspection (for clean-restore when no profile dir exists yet)
  #   4. Default standard location         (~/.mozilla/firefox)
  local snap_profile="$HOME/snap/firefox/common/.mozilla/firefox"
  local flatpak_profile="$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
  local ff_cmd ff_real

  # Prefer an already-existing profile directory (most reliable signal)
  if [[ -d "$snap_profile" ]]; then
    FF_DIR="$snap_profile"
  elif [[ -d "$flatpak_profile" ]]; then
    FF_DIR="$flatpak_profile"
  else
    # No existing profile yet – inspect the Firefox binary/wrapper
    ff_cmd="$(command -v firefox 2>/dev/null || true)"
    if [[ -n "$ff_cmd" ]]; then
      ff_real="$(readlink -f "$ff_cmd" 2>/dev/null || true)"
      if [[ "$ff_real" == */snap/firefox/* ]] || grep -qF "/snap/firefox/" "$ff_cmd" 2>/dev/null; then
        FF_DIR="$snap_profile"
      elif grep -qF "org.mozilla.firefox" "$ff_cmd" 2>/dev/null; then
        FF_DIR="$flatpak_profile"
      fi
      # else FF_DIR stays as the default set at the top of the script
    fi
  fi

  PROFILES_INI="$FF_DIR/profiles.ini"
  log "Firefox profile directory: $FF_DIR"
}

_usb_mounts_via_lsblk_tran() {
  lsblk -P -o NAME,TRAN,MOUNTPOINT,LABEL,SIZE,FSTYPE 2>/dev/null | awk '
    function uq(s) { gsub(/^"/, "", s); gsub(/"$/, "", s); return s }
    {
      name=tran=mp=label=size=fs=""
      for (i=1; i<=NF; i++) {
        split($i, kv, "=")
        key=kv[1]
        val=uq(kv[2])
        if (key=="NAME") name=val
        else if (key=="TRAN") tran=val
        else if (key=="MOUNTPOINT") mp=val
        else if (key=="LABEL") label=val
        else if (key=="SIZE") size=val
        else if (key=="FSTYPE") fs=val
      }
      if (tran=="usb" && mp!="")
        printf "%s\t/dev/%s\t%s\t%s\t%s\n", mp, name,
               (label==""?"-":label), (size==""?"?":size), (fs==""?"?":fs)
    }
  '
}

_usb_mounts_via_lsblk_removable() {
  lsblk -P -o NAME,RM,MOUNTPOINT,LABEL,SIZE,FSTYPE 2>/dev/null | awk '
    function uq(s) { gsub(/^"/, "", s); gsub(/"$/, "", s); return s }
    {
      name=rm=mp=label=size=fs=""
      for (i=1; i<=NF; i++) {
        split($i, kv, "=")
        key=kv[1]
        val=uq(kv[2])
        if (key=="NAME") name=val
        else if (key=="RM") rm=val
        else if (key=="MOUNTPOINT") mp=val
        else if (key=="LABEL") label=val
        else if (key=="SIZE") size=val
        else if (key=="FSTYPE") fs=val
      }
      if (rm=="1" && mp!="") {
        if (name ~ /^(sr|loop|zram)/) next
        printf "%s\t/dev/%s\t%s\t%s\t%s\n", mp, name,
               (label==""?"-":label), (size==""?"?":size), (fs==""?"?":fs)
      }
    }
  '
}

_usb_mounts_via_sysfs() {
  local sysdev real devname

  for sysdev in /sys/block/sd*; do
    [[ -e "$sysdev" ]] || continue
    real="$(readlink -f "$sysdev" 2>/dev/null || true)"
    [[ -n "$real" ]] || continue
    [[ "$real" == *"/usb"* ]] || continue
    devname="$(basename "$sysdev")"

    lsblk -P -o NAME,MOUNTPOINT,LABEL,SIZE,FSTYPE "/dev/$devname" 2>/dev/null | awk '
      function uq(s) { gsub(/^"/, "", s); gsub(/"$/, "", s); return s }
      {
        name=mp=label=size=fs=""
        for (i=1; i<=NF; i++) {
          split($i, kv, "=")
          key=kv[1]
          val=uq(kv[2])
          if (key=="NAME") name=val
          else if (key=="MOUNTPOINT") mp=val
          else if (key=="LABEL") label=val
          else if (key=="SIZE") size=val
          else if (key=="FSTYPE") fs=val
        }
        if (mp!="")
          printf "%s\t/dev/%s\t%s\t%s\t%s\n", mp, name,
                 (label==""?"-":label), (size==""?"?":size), (fs==""?"?":fs)
      }
    '
  done
}

_usb_collect_mounts() {
  local mounts="" extra=""

  log "Looking for mounted USB drives..."

  mounts="$(_usb_mounts_via_lsblk_tran || true)"
  if [[ -n "$mounts" ]]; then
    log "Found USB drives via transport detection."
  else
    log "No USB drives found via transport detection. Trying removable-device detection..."
    mounts="$(_usb_mounts_via_lsblk_removable || true)"
  fi

  if [[ -z "$mounts" ]]; then
    log "No USB drives found via removable-device detection. Trying sysfs fallback..."
    mounts="$(_usb_mounts_via_sysfs || true)"
  fi

  if [[ -n "$mounts" ]]; then
    extra="$(_usb_mounts_via_lsblk_removable || true)"
    if [[ -n "$extra" ]]; then
      mounts="$(printf '%s\n%s\n' "$mounts" "$extra")"
    fi
  fi

  printf '%s\n' "$mounts" | awk -F'\t' 'NF && !seen[$1]++' | sort
}

_verify_mount_path() {
  local path="$1" probe
  log "Verifying USB path: $path"

  [[ -d "$path" ]] || die "Path does not exist: $path"

  if ! findmnt -M "$path" >/dev/null 2>&1 && ! mountpoint -q "$path" 2>/dev/null; then
    warn "Path exists but does not look like a mount point: $path"
  fi

  probe="$path/.firefox-usb-probe.$$"
  touch "$probe" 2>/dev/null || die "USB path is not writable: $path"
  rm -f "$probe"
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

_profile_path_from_spec() {
  local spec="$1"
  local rel path resolved

  rel="${spec%%:*}"
  path="${spec#*:}"

  if [[ "$rel" == "1" ]]; then
    resolved="$FF_DIR/$path"
  else
    resolved="$path"
  fi

  [[ -d "$resolved" ]] || return 1
  printf '%s\n' "$resolved"
}

detect_default_profile() {
  local line spec
  local -a default_specs=() other_specs=()

  log "Looking for Firefox profiles in: $PROFILES_INI"
  [[ -f "$PROFILES_INI" ]] || die "profiles.ini not found: $PROFILES_INI"

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    if [[ "${line%%$'\t'*}" == "1" ]]; then
      default_specs+=("${line#*$'\t'}")
    else
      other_specs+=("${line#*$'\t'}")
    fi
  done < <(
    awk '
      BEGIN { in_profile=0; path=""; rel="1"; def="0" }
      function flush() {
        if (in_profile && path != "")
          printf "%s\t%s\n", def, rel ":" path
      }
      /^\[Profile[0-9]+\]$/ {
        flush()
        in_profile=1
        path=""
        rel="1"
        def="0"
        next
      }
      /^\[/ {
        flush()
        in_profile=0
        next
      }
      in_profile && /^Path=/ {
        sub(/^Path=/, "", $0)
        path=$0
        next
      }
      in_profile && /^IsRelative=/ {
        sub(/^IsRelative=/, "", $0)
        rel=$0
        next
      }
      in_profile && /^Default=1$/ {
        def="1"
        next
      }
      END { flush() }
    ' "$PROFILES_INI"
  )

  DEFAULT_PROFILE_SPEC=""
  PROFILE_DIR=""

  for spec in "${default_specs[@]}"; do
    if PROFILE_DIR="$(_profile_path_from_spec "$spec")"; then
      DEFAULT_PROFILE_SPEC="$spec"
      break
    fi
  done

  if [[ -z "$DEFAULT_PROFILE_SPEC" ]]; then
    warn "Default profile entry is missing or stale. Falling back to first existing profile."
    for spec in "${other_specs[@]}" "${default_specs[@]}"; do
      if PROFILE_DIR="$(_profile_path_from_spec "$spec")"; then
        DEFAULT_PROFILE_SPEC="$spec"
        break
      fi
    done
  fi

  [[ -n "$DEFAULT_PROFILE_SPEC" ]] || die "Could not find any existing Firefox profile directory."

  IS_RELATIVE="${DEFAULT_PROFILE_SPEC%%:*}"
  PROFILE_PATH_RAW="${DEFAULT_PROFILE_SPEC#*:}"
  PROFILE_BASENAME="$(basename "$PROFILE_DIR")"

  log "Detected Firefox profile: $PROFILE_DIR"
}

choose_backup_dir_for_restore() {
  local search_root="$1"
  local -a backups=()
  local count choice i

  log "Looking for Firefox backups in: $search_root"

  while IFS= read -r line; do
    [[ -n "$line" ]] && backups+=("$line")
  done < <(find "$search_root" -maxdepth 1 -type d -name 'firefox-profile-backup-*' | sort)

  count="${#backups[@]}"
  (( count > 0 )) || die "No firefox-profile-backup-* folders found in: $search_root"

  if (( count == 1 )); then
    BACKUP_DIR="${backups[0]}"
    log "One backup found. Using: $BACKUP_DIR"
    return 0
  fi

  echo
  echo "Available Firefox backups:"
  echo
  for (( i=0; i<count; i++ )); do
    printf '  [%-2d] %s\n' "$((i + 1))" "${backups[$i]}"
  done
  echo

  read -rp "Select backup [1-$count] (Enter for latest): " choice
  if [[ -z "$choice" ]]; then
    BACKUP_DIR="${backups[$((count - 1))]}"
    log "Using latest backup: $BACKUP_DIR"
    return 0
  fi

  [[ "$choice" =~ ^[0-9]+$ ]] || die "Selection must be a number."
  (( choice >= 1 && choice <= count )) || die "Invalid selection: $choice"

  BACKUP_DIR="${backups[$((choice - 1))]}"
  log "Selected backup: $BACKUP_DIR"
}

backup_mode() {
  local ts dest_root dest_profile_dir

  log "Starting Firefox backup..."
  detect_firefox_dir
  firefox_must_be_closed
  pick_usb_mount
  detect_default_profile

  ts="$(date +%Y%m%d-%H%M%S)"
  dest_root="$USB_MOUNT/firefox-profile-backup-$ts"
  if [[ "$IS_RELATIVE" == "1" ]]; then
    dest_profile_dir="$dest_root/$PROFILE_PATH_RAW"
  else
    dest_profile_dir="$dest_root/$PROFILE_BASENAME"
  fi

  log "Creating backup directory: $dest_root"
  mkdir -p "$dest_profile_dir"

  log "Copying Firefox profile..."
  rsync -aH --delete --info=progress2 "$PROFILE_DIR/" "$dest_profile_dir/"

  log "Copying profiles.ini..."
  cp -a "$PROFILES_INI" "$dest_root/profiles.ini"

  if [[ -f "$FF_DIR/installs.ini" ]]; then
    log "Copying installs.ini..."
    cp -a "$FF_DIR/installs.ini" "$dest_root/installs.ini"
  fi

  cat > "$dest_root/RESTORE-INFO.txt" <<EOF
Firefox profile backup
Created: $ts
Original Firefox dir: $FF_DIR
Original profile dir: $PROFILE_DIR
Original profile name: $PROFILE_BASENAME
EOF

  log "Backup complete."
  echo
  echo "Saved to:"
  echo "  $dest_root"
}

restore_mode() {
  local backup_profiles_ini backup_profile_dir ts safety

  log "Starting Firefox restore..."
  detect_firefox_dir
  firefox_must_be_closed

  if [[ -z "$BACKUP_DIR" ]]; then
    pick_usb_mount
    choose_backup_dir_for_restore "$USB_MOUNT"
  else
    [[ -d "$BACKUP_DIR" ]] || die "Backup directory not found: $BACKUP_DIR"
    log "Using backup directory from command line: $BACKUP_DIR"
  fi

  backup_profiles_ini="$BACKUP_DIR/profiles.ini"
  [[ -f "$backup_profiles_ini" ]] || die "Backup is missing profiles.ini: $backup_profiles_ini"

  backup_profile_dir="$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  [[ -n "$backup_profile_dir" && -d "$backup_profile_dir" ]] || die "Backup profile directory not found in: $BACKUP_DIR"

  mkdir -p "$(dirname "$FF_DIR")"

  if [[ -e "$FF_DIR" ]]; then
    ts="$(date +%Y%m%d-%H%M%S)"
    safety="$(dirname "$FF_DIR")/firefox.pre-restore-$ts"
    log "Saving current Firefox directory to: $safety"
    mv "$FF_DIR" "$safety"
  fi

  log "Creating fresh Firefox directory..."
  mkdir -p "$FF_DIR"

  log "Restoring profile directory..."
  cp -a "$backup_profile_dir" "$FF_DIR/"

  log "Restoring profiles.ini..."
  cp -a "$backup_profiles_ini" "$FF_DIR/profiles.ini"

  if [[ -f "$BACKUP_DIR/installs.ini" ]]; then
    log "Restoring installs.ini..."
    cp -a "$BACKUP_DIR/installs.ini" "$FF_DIR/installs.ini"
  fi

  log "Restore complete."
  echo
  echo "Start Firefox normally."
  echo "If Firefox does not open the restored profile automatically, run:"
  echo "  firefox -P"
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
  log "Parsing arguments..."
  parse_args "$@"
  log "Mode: $MODE"

  require_tools

  case "$MODE" in
    backup)  backup_mode ;;
    restore) restore_mode ;;
    *) die "Unsupported mode: $MODE" ;;
  esac
}

main "$@"
