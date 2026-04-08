#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="${0##*/}"
MODE=""
QUIET=0

FF_DIR="$HOME/.mozilla/firefox"
PROFILES_INI=""
USB_MOUNT=""
BACKUP_DIR=""

PROFILE_DIR=""
PROFILE_BASENAME=""
PROFILE_REL_PATH=""
PROFILE_NAME="restored"

trap 'rc=$?; printf "[%s] ERROR: failed near line %s (exit %s)\n" "$(date +%H:%M:%S)" "${BASH_LINENO[0]:-unknown}" "$rc" >&2; exit "$rc"' ERR

usage() {
  cat <<EOF
Usage:
  $SCRIPT_NAME backup [--usb PATH] [--quiet]
  $SCRIPT_NAME restore [--usb PATH] [--backup-dir PATH] [--quiet]
  $SCRIPT_NAME --help
EOF
}

log() {
  [[ "$QUIET" -eq 1 ]] && return 0
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2
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
  for cmd in awk grep sed cp mv rsync lsblk findmnt mkdir date basename dirname find sort tail head readlink pgrep mountpoint mktemp sync; do
    require_cmd "$cmd"
  done
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
  log "Firefox dir: $FF_DIR"
}

firefox_must_be_closed() {
  log "Checking that Firefox is fully closed..."
  # MainThread is common for Firefox child processes on some Linux systems.
  if pgrep -x firefox >/dev/null 2>&1 \
     || pgrep -x firefox-bin >/dev/null 2>&1 \
     || pgrep -x MainThread >/dev/null 2>&1; then
    die "Firefox appears to be running. Quit it completely and try again."
  fi
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
        printf "%s\t/dev/%s\t%s\t%s\t%s\n", mp, name, (label==""?"-":label), (size==""?"?":size), (fs==""?"?":fs)
      }
    }
  ' | awk -F'\t' '!seen[$1]++' | sort
}

pick_usb_mount() {
  local raw_mounts=""
  local -a mount_paths=() devices=() labels=() sizes=() fstypes=()
  local mp dev lbl sz fs count choice i

  if [[ -n "${USB_MOUNT:-}" ]]; then
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
  _verify_mount_path "$USB_MOUNT"
}

detect_default_profile() {
  local line rel path def resolved
  local -a defaults=() others=()

  [[ -f "$PROFILES_INI" ]] || die "profiles.ini not found: $PROFILES_INI"

  while IFS=$'\t' read -r def rel path; do
    [[ -n "$path" ]] || continue
    if [[ "$rel" == "1" ]]; then
      resolved="$FF_DIR/$path"
    else
      resolved="$path"
    fi
    [[ -d "$resolved" ]] || continue

    if [[ "$def" == "1" ]]; then
      defaults+=("$resolved")
    else
      others+=("$resolved")
    fi
  done < <(
    awk '
      BEGIN { in_profile=0; path=""; rel="1"; def="0" }
      function flush() {
        if (in_profile && path != "")
          printf "%s\t%s\t%s\n", def, rel, path
      }
      /^\[Profile[0-9]+\]$/ { flush(); in_profile=1; path=""; rel="1"; def="0"; next }
      /^\[/               { flush(); in_profile=0; next }
      in_profile && /^Path=/       { sub(/^Path=/, "", $0); path=$0; next }
      in_profile && /^IsRelative=/ { sub(/^IsRelative=/, "", $0); rel=$0; next }
      in_profile && /^Default=1$/  { def="1"; next }
      END { flush() }
    ' "$PROFILES_INI"
  )

  if ((${#defaults[@]} > 0)); then
    PROFILE_DIR="${defaults[0]}"
  elif ((${#others[@]} > 0)); then
    PROFILE_DIR="${others[0]}"
    warn "Default profile entry missing/stale; using first existing profile."
  else
    die "Could not find any existing Firefox profile directory."
  fi

  PROFILE_BASENAME="$(basename "$PROFILE_DIR")"
  PROFILE_REL_PATH="Profiles/$PROFILE_BASENAME"

  log "Using profile: $PROFILE_DIR"
}

write_restore_metadata() {
  local dest="$1"
  cat > "$dest/RESTORE-METADATA.conf" <<EOF
PROFILE_BASENAME='$PROFILE_BASENAME'
PROFILE_REL_PATH='$PROFILE_REL_PATH'
PROFILE_NAME='$PROFILE_NAME'
EOF
}

backup_mode() {
  local ts dest_root dest_profile_dir

  detect_firefox_dir
  firefox_must_be_closed
  pick_usb_mount
  detect_default_profile

  ts="$(date +%Y%m%d-%H%M%S)"
  dest_root="$USB_MOUNT/firefox-profile-backup-$ts"
  dest_profile_dir="$dest_root/profile"

  mkdir -p "$dest_profile_dir"

  log "Backing up profile to: $dest_root"
  rsync -aH --delete \
    --exclude='lock' \
    --exclude='.parentlock' \
    --exclude='*.sqlite-shm' \
    --exclude='*.sqlite-wal' \
    --exclude='cache2/' \
    --exclude='startupCache/' \
    --exclude='crashes/' \
    --exclude='minidumps/' \
    "$PROFILE_DIR/" "$dest_profile_dir/"

  write_restore_metadata "$dest_root"

  cat > "$dest_root/RESTORE-INFO.txt" <<EOF
Firefox profile backup
Created: $ts
Original Firefox dir: $FF_DIR
Original profile dir: $PROFILE_DIR
Original profile basename: $PROFILE_BASENAME
Restore strategy: copy profile into current install and regenerate profiles.ini
EOF

  sync
  echo
  echo "Saved to:"
  echo "  $dest_root"
}

choose_backup_dir_for_restore() {
  local search_root="$1"
  local -a backups=()
  local count choice i

  while IFS= read -r line; do
    [[ -n "$line" ]] && backups+=("$line")
  done < <(find "$search_root" -maxdepth 1 -type d -name 'firefox-profile-backup-*' | sort)

  count="${#backups[@]}"
  (( count > 0 )) || die "No firefox-profile-backup-* folders found in: $search_root"

  if (( count == 1 )); then
    BACKUP_DIR="${backups[0]}"
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
    return 0
  fi

  [[ "$choice" =~ ^[0-9]+$ ]] || die "Selection must be a number."
  (( choice >= 1 && choice <= count )) || die "Invalid selection: $choice"

  BACKUP_DIR="${backups[$((choice - 1))]}"
}

clean_restored_profile() {
  local profile_root="$1"

  [[ -d "$profile_root" ]] || return 0

  find "$profile_root" \
    \( -name 'lock' -o -name '.parentlock' -o -name '*.sqlite-wal' -o -name '*.sqlite-shm' \) \
    -type f -print0 | while IFS= read -r -d '' f; do
      rm -f -- "$f"
    done

  # Let the current Firefox install re-bind the profile cleanly.
  rm -f -- "$profile_root/compatibility.ini"
}

write_profiles_ini() {
  local target_rel="$1"
  cat > "$PROFILES_INI" <<EOF
[General]
StartWithLastProfile=1
Version=2

[Profile0]
Name=$PROFILE_NAME
IsRelative=1
Path=$target_rel
Default=1
EOF
}

restore_mode() {
  local backup_profile_dir metadata_file
  local target_profile_dir target_rel safety_root ts

  detect_firefox_dir
  firefox_must_be_closed

  if [[ -z "$BACKUP_DIR" ]]; then
    pick_usb_mount
    choose_backup_dir_for_restore "$USB_MOUNT"
  else
    [[ -d "$BACKUP_DIR" ]] || die "Backup directory not found: $BACKUP_DIR"
  fi

  backup_profile_dir="$BACKUP_DIR/profile"
  [[ -d "$backup_profile_dir" ]] || die "Backup profile directory not found: $backup_profile_dir"

  metadata_file="$BACKUP_DIR/RESTORE-METADATA.conf"
  if [[ -f "$metadata_file" ]]; then
    # shellcheck disable=SC1090
    source "$metadata_file"
  else
    warn "Metadata file missing; using backup folder basename."
    PROFILE_BASENAME="$(basename "$backup_profile_dir")"
    PROFILE_REL_PATH="Profiles/$PROFILE_BASENAME"
    PROFILE_NAME="restored"
  fi

  mkdir -p "$FF_DIR/Profiles"
  target_profile_dir="$FF_DIR/$PROFILE_REL_PATH"
  target_rel="$PROFILE_REL_PATH"

  if [[ -e "$target_profile_dir" ]]; then
    ts="$(date +%Y%m%d-%H%M%S)"
    safety_root="${target_profile_dir}.pre-restore-$ts"
    log "Moving existing target profile aside: $safety_root"
    mv "$target_profile_dir" "$safety_root"
  fi

  mkdir -p "$target_profile_dir"

  log "Restoring profile contents..."
  rsync -aH --delete "$backup_profile_dir/" "$target_profile_dir/"

  clean_restored_profile "$target_profile_dir"

  log "Writing fresh profiles.ini..."
  write_profiles_ini "$target_rel"

  # Important: do NOT restore old installs.ini from another machine/install.
  # Let Firefox regenerate it for the current installation.
  if [[ -f "$FF_DIR/installs.ini" ]]; then
    log "Removing stale installs.ini so Firefox can regenerate it..."
    rm -f -- "$FF_DIR/installs.ini"
  fi

  sync

  echo
  echo "Restore complete."
  echo "Start Firefox normally."
  echo
  echo "If Firefox still opens a different profile, run:"
  echo "  firefox -P"
  echo "and select/create the profile using folder:"
  echo "  $target_profile_dir"
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
    backup) backup_mode ;;
    restore) restore_mode ;;
    *) die "Unsupported mode: $MODE" ;;
  esac
}

main "$@"
