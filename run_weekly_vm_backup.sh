#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$BASE_DIR/logs"
LOG_FILE="$LOG_DIR/weekly_vm_backup.log"
LOCK_FILE="$BASE_DIR/.weekly_vm_backup.lock"
SELECTION_FILE="$BASE_DIR/vm_backup_selection.txt"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S %Z %z'
}

mkdir -p "$LOG_DIR"
exec >>"$LOG_FILE" 2>&1

echo "[$(timestamp)] Weekly VM list backup started."

if [ ! -s "$SELECTION_FILE" ]; then
  echo "[$(timestamp)] Selection file missing or empty: $SELECTION_FILE"
  exit 2
fi

set +e
(
  flock -n 9
  lock_status=$?
  if [ "$lock_status" -ne 0 ]; then
    echo "[$(timestamp)] Another VM list backup is still running. Exiting."
    exit 75
  fi

  cd "$BASE_DIR"
  ./start_select_vm_backup.sh --selection-file "$SELECTION_FILE" --yes
) 9>"$LOCK_FILE"
status=$?
set -e

if [ "$status" -eq 0 ]; then
  echo "[$(timestamp)] Weekly VM list backup completed."
else
  echo "[$(timestamp)] Weekly VM list backup failed with exit code $status."
fi

exit "$status"
