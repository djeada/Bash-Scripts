#!/usr/bin/env bash

###############################################################################
# Backup Script - backup.sh
#
# A robust, menu-driven backup utility that:
#   - Backs up user-selected directories (with defaults like Documents, Desktop,
#     Downloads) to a chosen location (local directory or USB drive).
#   - Optionally compresses (tar.gz) and/or encrypts (GPG) the backup.
#   - Provides advanced backup retention: daily, weekly, and monthly cleanup.
#   - Supports setting up a non-interactive cron job for automated backups.
#
###############################################################################

set -euo pipefail
IFS=$'\n\t'

# GLOBAL VARIABLES
CURRENT_BACKUP_FILE=""
VERBOSE=0

# COLORS
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# DEFAULT DIRECTORIES
DEFAULT_DIRS=(
  "$HOME/Documents"
  "$HOME/Downloads"
  "$HOME/Desktop"
)

# TRAP FOR CLEANUP
trap cleanup INT TERM EXIT

###############################################################################
# cleanup: Cleanup function triggered on exit or interruption
###############################################################################
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log ERROR "Script encountered an error. Cleaning up..."
    else
        log INFO "Script completed successfully."
    fi

    # Remove any partial backup if something failed
    if [[ -n "${CURRENT_BACKUP_FILE:-}" && -f "${CURRENT_BACKUP_FILE:-}" ]]; then
        log INFO "Removing incomplete backup file: ${CURRENT_BACKUP_FILE}"
        rm -f "${CURRENT_BACKUP_FILE}"
    fi

    exit $exit_code
}

###############################################################################
# log: Function for standardized log messages
###############################################################################
log() {
    local level="$1"
    shift
    local msg="$*"

    case "$level" in
        ERROR) echo -e "${RED}[ERROR] $msg${NC}" >&2 ;;
        WARN)  echo -e "${RED}[WARN] $msg${NC}" ;;
        INFO)  [[ $VERBOSE -ge 0 ]] && echo -e "${GREEN}[INFO] $msg${NC}" ;;
        DEBUG) [[ $VERBOSE -ge 1 ]] && echo -e "[DEBUG] $msg" ;;
    esac
}

###############################################################################
# press_enter_to_continue: Pauses until user presses Enter
###############################################################################
press_enter_to_continue() {
    echo
    read -r -p "Press [Enter] to continue..."
}

###############################################################################
# check_dependencies: Ensures required commands are installed
###############################################################################
check_dependencies() {
    local deps=(rsync tar date find gpg lsblk realpath crontab)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            log ERROR "Dependency '$dep' is required but not installed."
            exit 1
        fi
    done
}

###############################################################################
# detect_usb_drives: Returns a list of mountpoints for removable drives
###############################################################################
detect_usb_drives() {
    lsblk -o NAME,MOUNTPOINT,RM -nr | awk '$3=="1" && $2!="" {print $2}'
}

###############################################################################
# select_target_directory: Lets user pick a destination (custom path or USB)
###############################################################################
select_target_directory() {
    while true; do
        echo
        echo "Select Backup Destination:"
        echo "1) Enter a custom path"
        echo "2) Choose from detected USB drives"
        echo "3) Cancel"
        read -r -p "Enter your choice [1-3]: " choice
        case "$choice" in
            1)
                read -r -p "Enter full path for backup destination: " custom_path
                echo "$custom_path"
                return
                ;;
            2)
                local usb_drives=($(detect_usb_drives))
                if [[ ${#usb_drives[@]} -eq 0 ]]; then
                    log WARN "No USB drives detected. Connect a USB or select a custom path."
                    continue
                fi
                echo
                echo "Detected USB mount points:"
                local i=1
                for drive in "${usb_drives[@]}"; do
                    echo "$i) $drive"
                    ((i++))
                done
                read -r -p "Select a USB drive by number: " usb_choice
                if [[ "$usb_choice" =~ ^[0-9]+$ ]] && (( usb_choice >= 1 && usb_choice <= ${#usb_drives[@]} )); then
                    echo "${usb_drives[$((usb_choice-1))]}"
                    return
                else
                    log WARN "Invalid USB drive selection."
                fi
                ;;
            3)
                echo "Operation canceled."
                return
                ;;
            *)
                log WARN "Invalid choice. Try again."
                ;;
        esac
    done
}

###############################################################################
# select_source_directories: Lets user pick which directories to back up
###############################################################################
select_source_directories() {
    echo
    echo "Default directories to back up:"
    for dir in "${DEFAULT_DIRS[@]}"; do
        echo " - $dir"
    done
    echo
    echo "K) Keep these defaults"
    echo "A) Add more directories to these defaults"
    echo "C) Customize from scratch"
    read -r -p "Choose [K/A/C]: " ans
    case "$ans" in
        [Kk]*)
            echo "${DEFAULT_DIRS[@]}"
            ;;
        [Aa]*)
            read -r -p "Enter additional directories (space-separated): " extra_dirs
            echo "${DEFAULT_DIRS[@]} $extra_dirs"
            ;;
        [Cc]*)
            read -r -p "Enter the directories you want to back up (space-separated): " custom_dirs
            echo "$custom_dirs"
            ;;
        *)
            echo "${DEFAULT_DIRS[@]}"
            ;;
    esac
}

###############################################################################
# compress_backup: Compresses the backup folder into a tar.gz
###############################################################################
compress_backup() {
    local dir_path="$1"
    local tar_file="${dir_path}.tar.gz"
    log INFO "Compressing backup directory: $dir_path"
    tar -czf "$tar_file" -C "$(dirname "$dir_path")" "$(basename "$dir_path")"
    rm -rf "$dir_path"
    CURRENT_BACKUP_FILE="$tar_file"
    log INFO "Compression complete: $tar_file"
}

###############################################################################
# encrypt_backup: Encrypts the backup file using GPG and passphrase
###############################################################################
encrypt_backup() {
    local file_path="$1"
    local passphrase="$2"
    local enc_file="${file_path}.gpg"
    log INFO "Encrypting backup file: $file_path"
    echo "$passphrase" | gpg --batch --yes --passphrase-fd 0 --symmetric "$file_path"
    rm -f "$file_path"
    CURRENT_BACKUP_FILE="$enc_file"
    log INFO "Encryption complete: $enc_file"
}

###############################################################################
# advanced_retention_cleanup:
#   Allows daily, weekly, and monthly retention logic.
#   - Retains daily backups for X days
#   - Retains weekly backups for Y weeks
#   - Retains monthly backups for Z months
###############################################################################
advanced_retention_cleanup() {
    local backup_dir="$1"
    local daily_days="$2"
    local weekly_weeks="$3"
    local monthly_months="$4"

    log INFO "Performing advanced retention cleanup."
    log INFO "Daily: $daily_days days, Weekly: $weekly_weeks weeks, Monthly: $monthly_months months."

    find_daily_files() {
        find "$backup_dir" -maxdepth 1 -type f -name "backup_*" -mtime +"$daily_days"
    }
    find_weekly_files() {
        # Weekly backups can be older, but let's keep at least one per week for Y weeks
        # This is done by comparing the file's creation time to older than 7*Y days,
        # but skipping if we haven't found at least one backup in each 7-day block.
        # We'll do a simpler approach: first remove anything older than 7*Y, but daily
        # logic might have already removed many. Then we keep one per week in that range.
        local older_than_days=$(( weekly_weeks * 7 ))
        find "$backup_dir" -maxdepth 1 -type f -name "backup_*" -mtime +"$older_than_days"
    }
    find_monthly_files() {
        # Keep monthly backups for Z months
        local older_than_days=$(( monthly_months * 30 ))
        find "$backup_dir" -maxdepth 1 -type f -name "backup_*" -mtime +"$older_than_days"
    }

    # Remove daily backups older than daily_days
    if [[ "$daily_days" -gt 0 ]]; then
        while IFS= read -r old_file; do
            log INFO "Removing daily-old file: $old_file"
            rm -f "$old_file"
        done < <(find_daily_files || true)
    fi

    # Remove weekly backups older than weekly_weeks * 7 days
    if [[ "$weekly_weeks" -gt 0 ]]; then
        while IFS= read -r old_file; do
            log INFO "Removing weekly-old file: $old_file"
            rm -f "$old_file"
        done < <(find_weekly_files || true)
    fi

    # Remove monthly backups older than monthly_months * 30 days
    if [[ "$monthly_months" -gt 0 ]]; then
        while IFS= read -r old_file; do
            log INFO "Removing monthly-old file: $old_file"
            rm -f "$old_file"
        done < <(find_monthly_files || true)
    fi

    log INFO "Retention cleanup completed."
}

###############################################################################
# create_backup: Orchestrates the backup creation process
###############################################################################
create_backup() {
    local source_dirs=("$1")       # Actually an array but space-joined
    local dest_dir="$2"
    local compress="$3"
    local encrypt="$4"
    local gpg_pass="$5"
    local daily_retention="$6"
    local weekly_retention="$7"
    local monthly_retention="$8"

    log INFO "Starting backup..."
    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local backup_folder_name="backup_${timestamp}"
    local backup_folder_path="${dest_dir}/${backup_folder_name}"

    CURRENT_BACKUP_FILE="$backup_folder_path"
    mkdir -p "$backup_folder_path"

    local dir
    for dir in "${source_dirs[@]}"; do
        log INFO "Backing up: $dir"
        if [[ -d "$dir" ]]; then
            rsync -a --delete "${dir}/" "${backup_folder_path}/$(basename "$dir")"
        else
            log WARN "Skipping $dir (not found or not a directory)."
        fi
    done

    if [[ "$compress" == "true" ]]; then
        compress_backup "$backup_folder_path"
    fi

    if [[ "$encrypt" == "true" ]]; then
        encrypt_backup "$CURRENT_BACKUP_FILE" "$gpg_pass"
    fi

    log INFO "Backup complete: $CURRENT_BACKUP_FILE"
    advanced_retention_cleanup "$dest_dir" "$daily_retention" "$weekly_retention" "$monthly_retention"
}

###############################################################################
# configure_cron_job:
#   Sets up a cron entry for non-interactive backups.
#   This script relies on environment variables for truly automated backups.
###############################################################################
configure_cron_job() {
    echo
    read -r -p "Enter hour (0-23) for daily backup: " hour
    read -r -p "Enter minute (0-59) for daily backup: " minute
    read -r -p "Enter full path to this script: " script_path

    # Example environment-based line in crontab:
    #   DAILY_RETENTION=7 WEEKLY_RETENTION=4 MONTHLY_RETENTION=12 \
    #   SOURCE_DIRS=\"/home/user/Documents /home/user/Desktop\" \
    #   TARGET_DIR=\"/media/usb\" COMPRESS=true ENCRYPT=false \
    #   GPG_PASSPHRASE=\"secret\" bash /path/to/backup.sh --auto
    #
    # The user should place their chosen environment variables in the line below.
    #
    # For demonstration, we add a line that calls the script with a placeholder
    # environment. Adjust to your own environment variables or remove them.
    local cron_line="${minute} ${hour} * * * DAILY_RETENTION=7 WEEKLY_RETENTION=4 MONTHLY_RETENTION=1 SOURCE_DIRS=\"\$HOME/Documents \$HOME/Downloads \$HOME/Desktop\" TARGET_DIR=\"/media/usb\" COMPRESS=true ENCRYPT=false GPG_PASSPHRASE=\"secret\" bash \"${script_path}\" --auto"

    (crontab -l 2>/dev/null || true; echo "$cron_line") | crontab -
    log INFO "Cron job added to run daily at $hour:$minute."
}

###############################################################################
# auto_mode: Non-interactive mode for cron
###############################################################################
auto_mode() {
    local daily_retention="${DAILY_RETENTION:-7}"
    local weekly_retention="${WEEKLY_RETENTION:-4}"
    local monthly_retention="${MONTHLY_RETENTION:-3}"
    local source_dirs_str="${SOURCE_DIRS:-"$HOME/Documents $HOME/Downloads $HOME/Desktop"}"
    local target_dir="${TARGET_DIR:-"/tmp/backups"}"
    local compress="${COMPRESS:-"false"}"
    local encrypt="${ENCRYPT:-"false"}"
    local passphrase="${GPG_PASSPHRASE:-""}"

    IFS=' ' read -r -a source_array <<< "$source_dirs_str"

    create_backup \
        "${source_array[@]}" \
        "$target_dir" \
        "$compress" \
        "$encrypt" \
        "$passphrase" \
        "$daily_retention" \
        "$weekly_retention" \
        "$monthly_retention"
}

###############################################################################
# main_menu: Interactive menu for normal usage
###############################################################################
main_menu() {
    while true; do
        clear
        echo "========================================="
        echo "              Backup Script"
        echo "========================================="
        echo "1) Perform Backup"
        echo "2) Configure Automated Cron Job"
        echo "3) Quit"
        echo
        read -r -p "Enter your choice [1-3]: " main_choice
        case "$main_choice" in
            1)
                local source_dirs=($(select_source_directories))
                if [[ ${#source_dirs[@]} -eq 0 ]]; then
                    log WARN "No directories selected. Backup canceled."
                    press_enter_to_continue
                    continue
                fi
                local target_dir
                target_dir="$(select_target_directory)"
                if [[ -z "$target_dir" ]]; then
                    log WARN "No target directory selected. Backup canceled."
                    press_enter_to_continue
                    continue
                fi

                local compress="false"
                local encrypt="false"
                local gpg_passphrase=""
                local daily_retention=7
                local weekly_retention=4
                local monthly_retention=3

                echo
                read -r -p "Enable compression? (y/n): " ans
                if [[ "$ans" =~ ^[Yy]$ ]]; then
                    compress="true"
                fi
                echo
                read -r -p "Enable encryption? (y/n): " ans
                if [[ "$ans" =~ ^[Yy]$ ]]; then
                    encrypt="true"
                    read -r -s -p "Enter GPG passphrase: " gpg_passphrase
                    echo
                    if [[ -z "$gpg_passphrase" ]]; then
                        log ERROR "Encryption passphrase cannot be empty."
                        press_enter_to_continue
                        continue
                    fi
                fi
                echo
                echo "Enter retention policy for old backups."
                read -r -p "Daily retention (days): " daily_retention
                read -r -p "Weekly retention (weeks): " weekly_retention
                read -r -p "Monthly retention (months): " monthly_retention

                create_backup \
                    "${source_dirs[@]}" \
                    "$target_dir" \
                    "$compress" \
                    "$encrypt" \
                    "$gpg_passphrase" \
                    "$daily_retention" \
                    "$weekly_retention" \
                    "$monthly_retention"
                press_enter_to_continue
                ;;
            2)
                configure_cron_job
                press_enter_to_continue
                ;;
            3)
                echo "Goodbye."
                break
                ;;
            *)
                log WARN "Invalid choice."
                press_enter_to_continue
                ;;
        esac
    done
}

###############################################################################
# ENTRY POINT
###############################################################################
check_dependencies

if [[ "${1:-}" == "-v" ]]; then
    VERBOSE=1
    shift
fi

# Non-interactive mode for automation
if [[ "${1:-}" == "--auto" ]]; then
    auto_mode
    exit 0
fi

main_menu
